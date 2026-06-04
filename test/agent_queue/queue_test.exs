defmodule AgentQueue.QueueTest do
  use ExUnit.Case, async: true

  alias AgentQueue.Queue

  @now ~U[2026-06-04 00:00:00Z]

  test "enqueue, claim, complete, and stats are pure state transitions" do
    queue = Queue.new()

    {job, queue} = Queue.enqueue(queue, %{task: "write tests"}, id: "job-1", now: @now)
    assert job.status == :queued

    assert Queue.stats(queue) == %{
             queued: 1,
             running: 0,
             retrying: 0,
             completed: 0,
             failed: 0,
             blocked: 0
           }

    assert {:ok, running, queue} = Queue.claim_next(queue, 10)
    assert running.status == :running
    assert running.attempts == 1
    assert Queue.stats(queue).running == 1

    assert {:ok, completed, queue} = Queue.complete(queue, "job-1")
    assert completed.status == :completed
    assert Queue.stats(queue).completed == 1
  end

  test "failed jobs retry when due and eventually fail when attempts are exhausted" do
    queue = Queue.new()
    {_job, queue} = Queue.enqueue(queue, %{task: "flaky"}, id: "job-1", now: @now)
    {:ok, _running, queue} = Queue.claim_next(queue, 10)

    assert {:retrying, retrying, queue} =
             Queue.fail(queue, "job-1", :temporary_failure,
               now_ms: 10,
               backoff_ms: 50,
               max_attempts: 2
             )

    assert retrying.status == :retrying
    assert retrying.retry_at == 60
    assert {:empty, _queue} = Queue.claim_next(queue, 59)

    assert {:ok, running_again, queue} = Queue.claim_next(queue, 60)
    assert running_again.attempts == 2

    assert {:failed, failed, queue} =
             Queue.fail(queue, "job-1", :permanent_failure,
               now_ms: 70,
               backoff_ms: 50,
               max_attempts: 2
             )

    assert failed.status == :failed
    assert Queue.stats(queue).failed == 1
  end

  test "blocked jobs are separated from retryable failures" do
    queue = Queue.new()
    {_job, queue} = Queue.enqueue(queue, %{task: "needs human"}, id: "job-1", now: @now)
    {:ok, _running, queue} = Queue.claim_next(queue, 10)

    assert {:blocked, blocked, queue} = Queue.block(queue, "job-1", :operator_input_required)

    assert blocked.status == :blocked
    assert blocked.last_error == :operator_input_required
    assert Queue.stats(queue).blocked == 1
  end
end
