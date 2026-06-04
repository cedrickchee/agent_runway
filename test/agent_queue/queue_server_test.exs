defmodule AgentQueue.QueueServerTest do
  use ExUnit.Case

  alias AgentQueue.QueueServer

  test "the queue becomes a named process that owns state" do
    name = unique_name(:queue_server)
    start_supervised!({QueueServer, name: name})

    assert {:ok, job} = QueueServer.enqueue(name, %{task: "actor"}, id: "job-1")
    assert job.status == :queued

    assert {:ok, running} = QueueServer.claim(name)
    assert running.status == :running

    assert {:ok, completed} = QueueServer.complete(name, "job-1")
    assert completed.status == :completed
    assert QueueServer.stats(name).completed == 1
  end

  test "retry timers move retrying jobs back into the queue" do
    name = unique_name(:queue_server)
    start_supervised!({QueueServer, name: name})

    {:ok, _job} = QueueServer.enqueue(name, %{task: "retry"}, id: "job-1")
    {:ok, _running} = QueueServer.claim(name)

    assert {:retrying, retrying} =
             QueueServer.fail(name, "job-1", :temporary_failure,
               backoff_ms: 1,
               max_attempts: 2
             )

    assert retrying.status == :retrying
    Process.sleep(10)

    assert {:ok, running_again} = QueueServer.claim(name)
    assert running_again.status == :running
    assert running_again.attempts == 2
  end

  defp unique_name(prefix) do
    :"#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
  end
end
