defmodule AgentQueue.FakeTracker do
  @moduledoc """
  Stateful fake Linear adapter.

  This lets the orchestrator learn polling and reconciliation without making
  external API calls.
  """

  use Agent

  alias AgentQueue.Issue

  @active_states ["Ready", "Rework", "In Progress"]

  def start_link(opts \\ []) do
    issues = Keyword.get(opts, :issues, [])
    Agent.start_link(fn -> Map.new(issues, &{&1.id, &1}) end, Keyword.take(opts, [:name]))
  end

  def fetch_candidates(server, active_states \\ @active_states) do
    active = MapSet.new(Enum.map(active_states, &String.downcase(to_string(&1))))

    issues =
      Agent.get(server, fn issues ->
        issues
        |> Map.values()
        |> Enum.filter(fn %Issue{state: state} ->
          MapSet.member?(active, String.downcase(state))
        end)
        |> Enum.sort_by(&{&1.priority || 999, &1.identifier})
      end)

    {:ok, issues}
  end

  def fetch_state(server, issue_id) do
    Agent.get(server, fn issues ->
      case Map.fetch(issues, issue_id) do
        {:ok, issue} -> {:ok, issue.state}
        :error -> {:error, :not_found}
      end
    end)
  end

  def put_issue(server, %Issue{} = issue) do
    Agent.update(server, &Map.put(&1, issue.id, issue))
  end

  def set_state(server, issue_id, state) do
    Agent.update(server, fn issues ->
      Map.update!(issues, issue_id, &%{&1 | state: state})
    end)
  end
end
