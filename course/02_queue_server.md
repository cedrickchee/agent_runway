# 02 Queue Server

## Learning Objective

Understand `GenServer` as "one process owns state and receives messages", not
as magic framework machinery.

## Failure Story

The pure queue works only if the caller carefully threads the latest queue
value through every function. A real orchestrator cannot rely on that.

The failure:

```text
No living owner -> no authoritative runtime state
```

The answer is `AgentQueue.QueueServer`.

## Code Reading Path

Read:

- [`../lib/agent_queue/queue_server.ex`](../lib/agent_queue/queue_server.ex)
- [`../test/agent_queue/queue_server_test.exs`](../test/agent_queue/queue_server_test.exs)
- [`../lib/agent_queue/application.ex`](../lib/agent_queue/application.ex)

Focus on:

- `start_link/1`
- public API functions like `enqueue/3`
- `init/1`
- `handle_call/3`
- `handle_info/2`
- `Process.send_after/3`

## Walkthrough

The public API hides message details:

```elixir
def enqueue(server \\ __MODULE__, payload, opts \\ []) do
  GenServer.call(server, {:enqueue, payload, opts})
end
```

The process receives that message here:

```elixir
def handle_call({:enqueue, payload, opts}, _from, queue) do
  {job, queue} = Queue.enqueue(queue, payload, opts)
  {:reply, {:ok, job}, queue}
end
```

That final `queue` is important. It becomes the next process state.

The retry timer introduces a new kind of message:

```elixir
Process.send_after(self(), :retry_due, delay)
```

Later, the process handles it:

```elixir
def handle_info(:retry_due, queue) do
  {:noreply, Queue.retry_due(queue)}
end
```

Now the queue can wake itself up without an external caller.

## Hands-On Lab

Run:

```bash
mix test test/agent_queue/queue_server_test.exs
```

In `iex -S mix`:

```elixir
{:ok, pid} = AgentQueue.QueueServer.start_link(name: :lesson_queue)
AgentQueue.QueueServer.enqueue(:lesson_queue, %{task: "actor state"}, id: "job-1")
AgentQueue.QueueServer.claim(:lesson_queue)
AgentQueue.QueueServer.stats(:lesson_queue)
AgentQueue.QueueServer.complete(:lesson_queue, "job-1")
AgentQueue.QueueServer.stats(:lesson_queue)
```

The state lives inside the process, not in your shell variable.

## Break It Exercise

Ask yourself what would happen if `QueueServer` executed long-running agent
work inside `handle_call/3`.

Try simulating a blocked state owner mentally:

```elixir
def handle_call(:bad_idea, _from, queue) do
  Process.sleep(10_000)
  {:reply, :ok, queue}
end
```

What happens to every other message in the mailbox during that sleep?

## Full Walkthrough Solution

The process mailbox is sequential. That is good for state consistency and bad
for long-running work.

If the state owner sleeps for 10 seconds, it cannot process:

- new enqueue calls
- completion calls
- retry timer messages
- stats calls

This earns the next abstraction:

```text
State owner should coordinate work, not perform work -> external workers
```

In Symphony terms, the orchestrator should not become the agent. It should
start, observe, and classify agent runs.

## Reflection Questions

- Why does `GenServer.call/2` fit `enqueue/3` and `stats/1`?
- Why is `handle_info/2` used for timers?
- What is the difference between process state and module attributes?

## Checkpoint

Before moving on, you should be able to say:

> A `GenServer` is an actor-shaped state owner. It serializes state changes
> through its mailbox, which is exactly why long-running work must leave it.
