# 05 Orchestrator

## Learning Objective

Understand why AgentRunway promotes the queue into an orchestrator: polling,
dispatch, retry, blocking, reconciliation, and observability all need one
authoritative runtime owner.

## Failure Story

Once workers, retries, and issue polling exist, state starts to fragment.

The failure:

```text
Polling, dispatch, retry, cancellation, and completion compete for truth
```

The answer is not "more callbacks". The answer is one process that owns the
runtime model.

## Code Reading Path

Read:

- [`../lib/agent_queue/orchestrator.ex`](../lib/agent_queue/orchestrator.ex)
- [`../lib/agent_queue/fake_tracker.ex`](../lib/agent_queue/fake_tracker.ex)
- [`../test/agent_queue/orchestrator_test.exs`](../test/agent_queue/orchestrator_test.exs)

Focus on:

- the orchestrator struct fields
- `poll_tracker/1`
- `reconcile_running/1`
- `dispatch_until_full/1`
- `handle_info/2`
- `record/3`

## Walkthrough

The orchestrator struct is the runtime map:

```elixir
defstruct queue: Queue.new(),
          running: %{},
          claimed: MapSet.new(),
          seen_issue_ids: MapSet.new(),
          events: [],
          ...
```

Each field answers one operational question:

- `queue`: what work exists and what status is it in?
- `running`: which task refs map to active jobs?
- `claimed`: which issue IDs are already owned by this runtime?
- `seen_issue_ids`: which tracker issues have already entered the system?
- `events`: what happened recently?

Polling is an input:

```elixir
tracker.fetch_candidates(state.tracker_ref)
```

Dispatch is a decision:

```elixir
Queue.claim_next(state.queue)
```

Task replies are outputs coming back:

```elixir
handle_info({ref, {:ok, result}}, state)
```

Terminal issue reconciliation is another input:

```elixir
tracker.fetch_state(acc.tracker_ref, job_id)
```

The orchestrator is where these streams become one ordered sequence of state
transitions.

## Hands-On Lab

In `iex -S mix`:

```elixir
issue = %AgentQueue.Issue{
  id: "AGENT-1",
  identifier: "AGENT-1",
  title: "Observe orchestrator",
  state: "Ready",
  metadata: %{runner: :success, sleep_ms: 50}
}

{:ok, tracker} = AgentQueue.FakeTracker.start_link(issues: [issue])

{:ok, orchestrator} =
  AgentQueue.Orchestrator.start_link(
    tracker_ref: tracker,
    max_concurrent: 1,
    retry_backoff_ms: 100
  )

AgentQueue.Orchestrator.poll(orchestrator)
AgentQueue.Orchestrator.stats(orchestrator)
Process.sleep(100)
AgentQueue.Orchestrator.stats(orchestrator)
AgentQueue.Orchestrator.snapshot(orchestrator).events
```

Look at the event names. They are the system's story of itself.

## Break It Exercise

Change the issue to a slow run:

```elixir
metadata: %{runner: :success, sleep_ms: 5_000}
```

Start it, then change the tracker state:

```elixir
AgentQueue.FakeTracker.set_state(tracker, "AGENT-1", "Done")
AgentQueue.Orchestrator.poll(orchestrator)
AgentQueue.Orchestrator.stats(orchestrator)
```

Why should a terminal tracker state affect a running worker?

## Full Walkthrough Solution

In real orchestration, the issue tracker can change while an agent is running.
Someone might close, cancel, duplicate, or manually resolve the issue.

If the orchestrator ignores that, it may continue spending compute on work that
is no longer valid. If a worker decides on its own, state becomes fragmented.

AgentRunway centralizes the decision:

```text
tracker state changed -> orchestrator sees it -> worker is stopped -> job is blocked
```

This is reconciliation. The orchestrator compares external truth with runtime
truth and chooses a transition.

## Reflection Questions

- Why is `seen_issue_ids` different from `claimed`?
- Why is polling not allowed to start work directly?
- Why do all task outcomes pass through `handle_info/2`?

## Checkpoint

Before moving on, you should be able to explain:

- why the orchestrator owns runtime truth
- how polling and task messages are serialized
- how terminal issue state becomes local queue state
- why observability starts with explicit events
