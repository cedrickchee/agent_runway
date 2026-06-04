defmodule AgentQueue.Queue do
  @moduledoc """
  Phase 1: a pure queue state machine.

  This module intentionally has no processes. It is easy to test, but it also
  exposes the first failure: a pure state machine is not a living system.
  """

  alias AgentQueue.Job

  defstruct queued: [],
            running: %{},
            retrying: %{},
            completed: %{},
            failed: %{},
            blocked: %{}

  @type t :: %__MODULE__{
          queued: [Job.t()],
          running: %{optional(term()) => Job.t()},
          retrying: %{optional(term()) => Job.t()},
          completed: %{optional(term()) => Job.t()},
          failed: %{optional(term()) => Job.t()},
          blocked: %{optional(term()) => Job.t()}
        }

  def new, do: %__MODULE__{}

  def enqueue(%__MODULE__{} = queue, %Job{} = job) do
    job = Job.transition(job, :queued, retry_at: nil, last_error: nil)
    {job, %{queue | queued: queue.queued ++ [job]}}
  end

  def enqueue(%__MODULE__{} = queue, payload, opts \\ []) do
    enqueue(queue, Job.new(payload, opts))
  end

  def claim_next(%__MODULE__{} = queue, now_ms \\ AgentQueue.Clock.now_ms()) do
    queue = retry_due(queue, now_ms)

    case queue.queued do
      [] ->
        {:empty, queue}

      [job | rest] ->
        running = Job.transition(job, :running, attempts: job.attempts + 1, retry_at: nil)
        queue = %{queue | queued: rest, running: Map.put(queue.running, running.id, running)}
        {:ok, running, queue}
    end
  end

  def complete(%__MODULE__{} = queue, id) do
    move_from_active(queue, id, :completed)
  end

  def fail(%__MODULE__{} = queue, id, reason, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    backoff_ms = Keyword.get(opts, :backoff_ms, 1_000)
    now_ms = Keyword.get_lazy(opts, :now_ms, &AgentQueue.Clock.now_ms/0)

    case pop_active(queue, id) do
      {:ok, job, queue} when job.attempts < max_attempts ->
        retrying =
          Job.transition(job, :retrying,
            retry_at: now_ms + backoff_ms * max(job.attempts, 1),
            last_error: reason
          )

        {:retrying, retrying, %{queue | retrying: Map.put(queue.retrying, id, retrying)}}

      {:ok, job, queue} ->
        failed = Job.transition(job, :failed, retry_at: nil, last_error: reason)
        {:failed, failed, %{queue | failed: Map.put(queue.failed, id, failed)}}

      :error ->
        {:error, :not_found, queue}
    end
  end

  def block(%__MODULE__{} = queue, id, reason) do
    case pop_active(queue, id) do
      {:ok, job, queue} ->
        blocked = Job.transition(job, :blocked, retry_at: nil, last_error: reason)
        {:blocked, blocked, %{queue | blocked: Map.put(queue.blocked, id, blocked)}}

      :error ->
        {:error, :not_found, queue}
    end
  end

  def retry_due(%__MODULE__{} = queue, now_ms \\ AgentQueue.Clock.now_ms()) do
    {due, later} =
      Enum.split_with(queue.retrying, fn {_id, job} ->
        is_integer(job.retry_at) and job.retry_at <= now_ms
      end)

    queued =
      Enum.reduce(due, queue.queued, fn {_id, job}, acc ->
        acc ++ [Job.transition(job, :queued, retry_at: nil)]
      end)

    %{queue | queued: queued, retrying: Map.new(later)}
  end

  def stats(%__MODULE__{} = queue) do
    %{
      queued: length(queue.queued),
      running: map_size(queue.running),
      retrying: map_size(queue.retrying),
      completed: map_size(queue.completed),
      failed: map_size(queue.failed),
      blocked: map_size(queue.blocked)
    }
  end

  def find(%__MODULE__{} = queue, id) do
    Enum.find_value(
      [queue.running, queue.retrying, queue.completed, queue.failed, queue.blocked],
      fn bucket ->
        Map.get(bucket, id)
      end
    ) || Enum.find(queue.queued, &(&1.id == id))
  end

  defp move_from_active(queue, id, destination) do
    case pop_active(queue, id) do
      {:ok, job, queue} ->
        job = Job.transition(job, destination, retry_at: nil)
        bucket = Map.fetch!(queue, destination)
        {:ok, job, Map.put(queue, destination, Map.put(bucket, id, job))}

      :error ->
        {:error, :not_found, queue}
    end
  end

  defp pop_active(queue, id) do
    cond do
      Map.has_key?(queue.running, id) ->
        {job, running} = Map.pop!(queue.running, id)
        {:ok, job, %{queue | running: running}}

      Map.has_key?(queue.retrying, id) ->
        {job, retrying} = Map.pop!(queue.retrying, id)
        {:ok, job, %{queue | retrying: retrying}}

      true ->
        pop_queued(queue, id)
    end
  end

  defp pop_queued(queue, id) do
    case Enum.split_with(queue.queued, &(&1.id != id)) do
      {_before, []} ->
        :error

      {before, [job | after_jobs]} ->
        {:ok, job, %{queue | queued: before ++ after_jobs}}
    end
  end
end
