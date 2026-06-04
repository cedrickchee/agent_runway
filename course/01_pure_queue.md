# 01 Pure Queue

## Learning Objective

Learn Elixir's core data model by reading and exercising a pure queue state
machine. No processes yet. No OTP yet. Just values in, values out.

## Failure Story

A pure queue is excellent for local reasoning. It is also not a living system.

It cannot:

- wake itself up for retries
- receive completion messages
- observe worker crashes
- coordinate multiple callers
- preserve state unless the caller keeps the returned value

That failure is useful. It tells us exactly why a later process must own the
queue.

## Code Reading Path

Read:

- [`../lib/agent_queue/job.ex`](../lib/agent_queue/job.ex)
- [`../lib/agent_queue/queue.ex`](../lib/agent_queue/queue.ex)
- [`../test/agent_queue/queue_test.exs`](../test/agent_queue/queue_test.exs)

Focus on:

- `%AgentQueue.Job{}`
- `%AgentQueue.Queue{}`
- `enqueue/3`
- `claim_next/2`
- `complete/2`
- `fail/4`
- `retry_due/2`
- `stats/1`

## Walkthrough

`AgentQueue.Job` is a struct:

```elixir
%AgentQueue.Job{
  id: "job-1",
  payload: %{task: "write tests"},
  status: :queued,
  attempts: 0
}
```

If you come from JS, treat a struct like a map with a known shape. If you come
from Ruby, treat it like a lightweight value object. The important difference:
the project does not mutate the job in place. Transitions return new values.

The queue itself has buckets:

```elixir
%AgentQueue.Queue{
  queued: [],
  running: %{},
  retrying: %{},
  completed: %{},
  failed: %{},
  blocked: %{}
}
```

`claim_next/2` demonstrates the core style:

```elixir
case queue.queued do
  [] ->
    {:empty, queue}

  [job | rest] ->
    running = Job.transition(job, :running, attempts: job.attempts + 1)
    {:ok, running, new_queue}
end
```

There is no hidden state. The returned queue is the new truth.

## Hands-On Lab

Run only the pure queue tests:

```bash
mix test test/agent_queue/queue_test.exs
```

Open `iex`:

```bash
iex -S mix
```

Paste:

```elixir
queue = AgentQueue.Queue.new()
{job, queue} = AgentQueue.Queue.enqueue(queue, %{task: "learn OTP"}, id: "job-1")
AgentQueue.Queue.stats(queue)
{:ok, running, queue} = AgentQueue.Queue.claim_next(queue)
{:retrying, retrying, queue} = AgentQueue.Queue.fail(queue, "job-1", :temporary, backoff_ms: 100)
AgentQueue.Queue.stats(queue)
```

Observe that every step returns a new `queue`.

## Break It Exercise

In `iex`, intentionally ignore the returned queue:

```elixir
queue = AgentQueue.Queue.new()
AgentQueue.Queue.enqueue(queue, %{task: "lost"}, id: "job-1")
AgentQueue.Queue.stats(queue)
```

Why does `stats/1` still show an empty queue?

## Full Walkthrough Solution

`enqueue/3` does not mutate `queue`. It returns `{job, new_queue}`. If you
throw away `new_queue`, you throw away the state transition.

This is the point of Phase 1. Pure functions are easy to test, but someone
must hold the latest state. In a small script, that someone is you. In a
running system, that someone should be a process.

The failure earns the next abstraction:

```text
Pure queue needs a long-lived owner -> GenServer
```

## Reflection Questions

- Which queue functions are total enough to test without a process?
- What bugs become impossible because the queue is immutable?
- What bugs remain because there is no state owner?

## Checkpoint

Before moving on, you should be able to explain:

- how pattern matching chooses queue behavior
- why `{:ok, value, queue}` tuples are used
- why immutable state makes tests straightforward
- why pure functions alone do not make an orchestrator
