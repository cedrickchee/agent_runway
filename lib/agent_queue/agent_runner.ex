defmodule AgentQueue.AgentRunner do
  @moduledoc """
  Fake Codex runner boundary.

  The runner is deliberately configurable through issue metadata so tests can
  force success, failure, blocked, timeout-like slowness, and crashes.
  """

  alias AgentQueue.{Job, Workflow}

  @callback run(Job.t(), keyword()) ::
              {:ok, map()}
              | {:error, term()}
              | {:blocked, term()}

  def run(%Job{} = job, opts \\ []) do
    metadata = metadata(job)
    sleep_ms = Map.get(metadata, :sleep_ms, Map.get(metadata, "sleep_ms", 0))

    if sleep_ms > 0 do
      Process.sleep(sleep_ms)
    end

    case Map.get(metadata, :runner, Map.get(metadata, "runner", :success)) do
      :success ->
        {:ok, result(job, opts)}

      "success" ->
        {:ok, result(job, opts)}

      :fail ->
        {:error, :agent_reported_failure}

      "fail" ->
        {:error, :agent_reported_failure}

      :block ->
        {:blocked, :operator_input_required}

      "block" ->
        {:blocked, :operator_input_required}

      :crash ->
        raise "simulated agent crash"

      "crash" ->
        raise "simulated agent crash"
    end
  end

  defp result(%Job{} = job, opts) do
    %{
      job_id: job.id,
      workspace_path: Keyword.fetch!(opts, :workspace_path),
      prompt: Workflow.render_prompt(job.payload)
    }
  end

  defp metadata(%Job{payload: %{metadata: metadata}}) when is_map(metadata), do: metadata
  defp metadata(_job), do: %{}
end
