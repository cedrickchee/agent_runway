# Failure Map

This document is the point of the project: every OTP abstraction is introduced
because a simpler design fails.

## 1. Pure Queue

Start with `AgentQueue.Queue`.

What works:

- State transitions are obvious.
- Tests are fast.
- Pattern matching and immutable data are easy to see.

What fails:

- Nothing owns the queue.
- Nothing runs jobs.
- State disappears unless a caller holds onto the returned value.

Abstractions earned:

- Structs
- Pattern matching
- Function clauses
- ExUnit

## 2. QueueServer

Wrap the queue in `AgentQueue.QueueServer`.

What works:

- One process owns authoritative queue state.
- Callers interact through a mailbox.
- Retry timers can wake the process later.

What fails:

- Running long jobs inside this process would block the state owner.
- The queue process should coordinate work, not perform it.

Abstractions earned:

- `GenServer`
- Actor model
- Mailbox
- `call`
- `handle_info`
- Named processes

## 3. External Workers

Move execution into `AgentQueue.AgentRunner`.

What works:

- Job execution no longer blocks the queue owner.
- Success, failure, blocking, and crash behavior become explicit.

What fails:

- Unmanaged processes are hard to track.
- Crashes can disappear unless the owner observes them.
- Starting too many workers overloads the system.

Abstractions earned:

- Process isolation
- Task results
- Monitors
- Exit reasons

## 4. Supervised Workers

Run workers under `AgentQueue.WorkerSupervisor`.

What works:

- Worker lifecycles are contained.
- The orchestrator can track task references.
- Bounded concurrency makes load explicit.

What fails:

- Restarting blindly is not a retry policy.
- Some failures need backoff.
- Some failures need a blocked state instead of retry.

Abstractions earned:

- `Task.Supervisor`
- Supervision tree
- Bounded concurrency
- Crash containment

## 5. Orchestrator

Promote the state owner into `AgentQueue.Orchestrator`.

What works:

- Polling, dispatch, retries, blocked state, running tasks, and completed work
  share one source of truth.
- The orchestrator can reconcile issue state against the tracker.

What fails:

- External systems are unreliable.
- Workspace creation, issue polling, and agent execution need stable boundaries.

Abstractions earned:

- Timers
- Reconciliation loop
- Runtime state ownership
- Explicit failure mapping

## 6. Symphony Shape

Map the mini-project to Symphony.

- `AgentQueue.FakeTracker` stands in for the issue tracker client.
- `AgentQueue.Workflow` stands in for the workflow loader and prompt renderer.
- `AgentQueue.WorkspaceManager` stands in for per-issue workspace setup.
- `AgentQueue.AgentRunner` stands in for the Codex App Server runner.
- `AgentQueue.Orchestrator` owns runtime state, bounded concurrency, retries,
  blocked work, and observability.

The desired learning outcome is that Symphony's architecture feels like a
larger version of failures you have already seen locally.
