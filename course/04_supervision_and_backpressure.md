# 04 Supervision And Backpressure

## Learning Objective

Learn why supervision and bounded concurrency are part of correctness for
agent orchestration, not just operational polish.

## Failure Story

Moving work out of the queue process avoids blocking. But now the system can
start too much work and lose track of failures.

The failure:

```text
Unbounded unmanaged workers overload the runtime and hide crashes
```

The answer is supervised, bounded work.

## Code Reading Path

Read:

- [`../lib/agent_queue/application.ex`](../lib/agent_queue/application.ex)
- [`../lib/agent_queue/orchestrator.ex`](../lib/agent_queue/orchestrator.ex)
- [`../test/agent_queue/orchestrator_test.exs`](../test/agent_queue/orchestrator_test.exs)

Focus on:

- `Task.Supervisor`
- `max_concurrent`
- `dispatch_until_full/1`
- `put_running/2`
- `fail_claimed_job/3`
- `schedule_retry/1`

## Walkthrough

The application starts a named task supervisor:

```elixir
{Task.Supervisor, name: AgentQueue.WorkerSupervisor}
```

The orchestrator starts work under that supervisor:

```elixir
Task.Supervisor.async_nolink(state.task_supervisor, fn ->
  runner.run(job, workspace_path: workspace_path)
end)
```

`async_nolink` is deliberate. The worker crashing should not crash the
orchestrator. Instead, the orchestrator receives a `:DOWN` message and converts
that into queue state.

Backpressure appears in `dispatch_until_full/1`:

```elixir
if map_size(state.running) >= state.max_concurrent do
  state
else
  ...
end
```

This is simple, but it encodes a serious rule: if only one agent run should be
active, the second issue must wait.

## Hands-On Lab

Run the orchestrator tests:

```bash
mix test test/agent_queue/orchestrator_test.exs
```

Then inspect the bounded concurrency test:

```elixir
assert %{queued: 1, running_tasks: 1} = Orchestrator.stats(orchestrator)
```

That assertion is not incidental. It proves the orchestrator can refuse to
launch all available work.

## Break It Exercise

Read `dispatch_until_full/1` and imagine deleting this condition:

```elixir
map_size(state.running) >= state.max_concurrent
```

What would happen if the fake tracker returned 10,000 eligible issues?

## Full Walkthrough Solution

Without bounded concurrency, the orchestrator would try to start every eligible
run. In a real Codex system, that could exhaust:

- CPU
- memory
- filesystem capacity
- API quotas
- repository checkout resources
- human review bandwidth

Backpressure is not only performance. It protects correctness by keeping the
runtime inside known limits.

Crashes follow a separate policy. When a worker crashes, the task supervisor
contains the process failure. The orchestrator then decides whether the job
should retry or fail permanently:

```text
crash -> :DOWN -> orchestrator -> retry/fail state
```

This earns the next abstraction:

```text
Work is supervised, but policy belongs to the orchestrator
```

## Reflection Questions

- Why should the supervisor not decide retry policy by itself?
- What is the difference between restarting a process and retrying a job?
- What system resources should `max_concurrent` protect in a real agent fleet?

## Checkpoint

Before moving on, you should be able to explain:

- why `Task.Supervisor` exists in this project
- why `async_nolink` is useful here
- why bounded concurrency is correctness logic
- why retry/backoff is domain policy, not only process restart behavior
