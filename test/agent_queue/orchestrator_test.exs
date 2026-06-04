defmodule AgentQueue.OrchestratorTest do
  use ExUnit.Case

  alias AgentQueue.{FakeTracker, Issue, Orchestrator}

  test "polling the fake tracker starts and completes a supervised agent run" do
    issue = issue("AGENT-1", runner: :success)
    {:ok, tracker} = start_supervised({FakeTracker, issues: [issue]})
    {:ok, orchestrator} = start_orchestrator(tracker, max_concurrent: 1)

    assert :ok = Orchestrator.poll(orchestrator)

    assert_eventually(fn ->
      assert %{completed: 1, running_tasks: 0} = Orchestrator.stats(orchestrator)
    end)
  end

  test "bounded concurrency prevents all runnable issues from starting at once" do
    issues = [
      issue("AGENT-1", runner: :success, sleep_ms: 80),
      issue("AGENT-2", runner: :success, sleep_ms: 80)
    ]

    {:ok, tracker} = start_supervised({FakeTracker, issues: issues})
    {:ok, orchestrator} = start_orchestrator(tracker, max_concurrent: 1)

    assert :ok = Orchestrator.poll(orchestrator)
    Process.sleep(10)

    assert %{queued: 1, running_tasks: 1} = Orchestrator.stats(orchestrator)
  end

  test "reported failures use retry policy instead of blind restarts" do
    issue = issue("AGENT-1", runner: :fail)
    {:ok, tracker} = start_supervised({FakeTracker, issues: [issue]})
    {:ok, orchestrator} = start_orchestrator(tracker, max_concurrent: 1, max_attempts: 1)

    assert :ok = Orchestrator.poll(orchestrator)

    assert_eventually(fn ->
      assert %{failed: 1, running_tasks: 0} = Orchestrator.stats(orchestrator)
    end)
  end

  test "agent crashes are converted into orchestrator-owned failure state" do
    issue = issue("AGENT-1", runner: :crash)
    {:ok, tracker} = start_supervised({FakeTracker, issues: [issue]})
    {:ok, orchestrator} = start_orchestrator(tracker, max_concurrent: 1, max_attempts: 1)

    assert :ok = Orchestrator.poll(orchestrator)

    assert_eventually(fn ->
      assert %{failed: 1, running_tasks: 0} = Orchestrator.stats(orchestrator)
    end)
  end

  test "blocked results are not retried automatically" do
    issue = issue("AGENT-1", runner: :block)
    {:ok, tracker} = start_supervised({FakeTracker, issues: [issue]})
    {:ok, orchestrator} = start_orchestrator(tracker, max_concurrent: 1)

    assert :ok = Orchestrator.poll(orchestrator)

    assert_eventually(fn ->
      assert %{blocked: 1, retrying: 0, running_tasks: 0} = Orchestrator.stats(orchestrator)
    end)
  end

  test "terminal issue reconciliation stops running work" do
    issue = issue("AGENT-1", runner: :success, sleep_ms: 200)
    {:ok, tracker} = start_supervised({FakeTracker, issues: [issue]})
    {:ok, orchestrator} = start_orchestrator(tracker, max_concurrent: 1)

    assert :ok = Orchestrator.poll(orchestrator)
    Process.sleep(10)
    FakeTracker.set_state(tracker, issue.id, "Done")
    assert :ok = Orchestrator.poll(orchestrator)

    assert_eventually(fn ->
      assert %{blocked: 1, running_tasks: 0} = Orchestrator.stats(orchestrator)
    end)
  end

  defp start_orchestrator(tracker, opts) do
    opts =
      Keyword.merge(
        [
          tracker_ref: tracker,
          workspace_root: workspace_root(),
          retry_backoff_ms: 5,
          poll_interval_ms: 25
        ],
        opts
      )

    start_supervised({Orchestrator, opts})
  end

  defp issue(identifier, metadata) do
    %Issue{
      id: identifier,
      identifier: identifier,
      title: "Handle #{identifier}",
      description: "Synthetic issue for orchestrator tests.",
      state: "Ready",
      metadata: Map.new(metadata)
    }
  end

  defp workspace_root do
    Path.join(System.tmp_dir!(), "agent_queue_test_#{System.unique_integer([:positive])}")
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    try do
      fun.()
    rescue
      ExUnit.AssertionError ->
        Process.sleep(20)
        assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(fun, 0), do: fun.()
end
