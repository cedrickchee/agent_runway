defmodule AgentQueue.QueueServer do
  @moduledoc """
  Phase 2: the pure queue becomes an actor.

  The process owns one `AgentQueue.Queue` value and serializes access through
  its mailbox.
  """

  use GenServer

  alias AgentQueue.Queue

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def enqueue(server \\ __MODULE__, payload, opts \\ []) do
    GenServer.call(server, {:enqueue, payload, opts})
  end

  def claim(server \\ __MODULE__) do
    GenServer.call(server, :claim)
  end

  def complete(server \\ __MODULE__, id) do
    GenServer.call(server, {:complete, id})
  end

  def fail(server \\ __MODULE__, id, reason, opts \\ []) do
    GenServer.call(server, {:fail, id, reason, opts})
  end

  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(_opts) do
    {:ok, Queue.new()}
  end

  @impl true
  def handle_call({:enqueue, payload, opts}, _from, queue) do
    {job, queue} = Queue.enqueue(queue, payload, opts)
    {:reply, {:ok, job}, queue}
  end

  def handle_call(:claim, _from, queue) do
    case Queue.claim_next(queue) do
      {:ok, job, queue} -> {:reply, {:ok, job}, queue}
      {:empty, queue} -> {:reply, :empty, queue}
    end
  end

  def handle_call({:complete, id}, _from, queue) do
    case Queue.complete(queue, id) do
      {:ok, job, queue} -> {:reply, {:ok, job}, queue}
      {:error, reason, queue} -> {:reply, {:error, reason}, queue}
    end
  end

  def handle_call({:fail, id, reason, opts}, _from, queue) do
    case Queue.fail(queue, id, reason, opts) do
      {:retrying, job, queue} ->
        schedule_retry(job)
        {:reply, {:retrying, job}, queue}

      {:failed, job, queue} ->
        {:reply, {:failed, job}, queue}

      {:error, reason, queue} ->
        {:reply, {:error, reason}, queue}
    end
  end

  def handle_call(:stats, _from, queue) do
    {:reply, Queue.stats(queue), queue}
  end

  def handle_call(:snapshot, _from, queue) do
    {:reply, queue, queue}
  end

  @impl true
  def handle_info(:retry_due, queue) do
    {:noreply, Queue.retry_due(queue)}
  end

  defp schedule_retry(%{retry_at: retry_at}) when is_integer(retry_at) do
    delay = max(retry_at - AgentQueue.Clock.now_ms(), 0)
    Process.send_after(self(), :retry_due, delay)
  end

  defp schedule_retry(_job), do: :ok
end
