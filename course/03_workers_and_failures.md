# 03 Workers And Failures

## Learning Objective

Understand why agent execution leaves the queue process and how success,
failure, blocking, and crashes become messages back to the orchestrator.

## Failure Story

The `QueueServer` gives us a living state owner. But if agent runs happen
inside that state owner, one slow run blocks the whole system.

The next failure:

```text
Long-running work inside the state owner blocks orchestration
```

Workers solve the blocking problem, but create a tracking problem.

## Code Reading Path

Read:

- [`../lib/agent_queue/agent_runner.ex`](../lib/agent_queue/agent_runner.ex)
- [`../lib/agent_queue/workflow.ex`](../lib/agent_queue/workflow.ex)
- [`../lib/agent_queue/orchestrator.ex`](../lib/agent_queue/orchestrator.ex)

In `AgentQueue.Orchestrator`, focus on:

- `start_agent/2`
- `handle_info({ref, {:ok, result}}, state)`
- `handle_info({ref, {:error, reason}}, state)`
- `handle_info({ref, {:blocked, reason}}, state)`
- `handle_info({:DOWN, ref, :process, _pid, reason}, state)`

## Walkthrough

`AgentQueue.AgentRunner` is a fake Codex runner boundary. It uses issue
metadata to decide what kind of run to simulate:

```elixir
%{runner: :success}
%{runner: :fail}
%{runner: :block}
%{runner: :crash}
```

Success returns data:

```elixir
{:ok, %{job_id: job.id, workspace_path: path, prompt: prompt}}
```

Failure returns a reason:

```elixir
{:error, :agent_reported_failure}
```

Blocked work returns a different reason:

```elixir
{:blocked, :operator_input_required}
```

Crash raises:

```elixir
raise "simulated agent crash"
```

The important idea is that the runner does not own queue state. It only
performs work and reports an outcome.

## Hands-On Lab

In `iex -S mix`, create a job and call the runner directly:

```elixir
issue = %AgentQueue.Issue{
  id: "AGENT-1",
  identifier: "AGENT-1",
  title: "Run fake agent",
  state: "Ready",
  metadata: %{runner: :success}
}

job = AgentQueue.Job.new(issue, id: issue.id)
AgentQueue.AgentRunner.run(job, workspace_path: "/tmp/agent-runway-demo")
```

Change `metadata` to `%{runner: :fail}` and `%{runner: :block}`.

For `%{runner: :crash}`, expect an exception. That is the point.

## Break It Exercise

Imagine starting a worker with raw `spawn(fn -> ... end)` and never monitoring
it.

Answer:

```text
If the process crashes, how does the orchestrator know which job failed?
```

Then read `pop_running_by_ref/2` in `AgentQueue.Orchestrator`.

## Full Walkthrough Solution

Unmanaged workers fix blocking but lose accountability. A crash has to be
connected back to a specific job.

AgentRunway uses supervised tasks and stores entries like:

```elixir
%{job: job, pid: task.pid, ref: task.ref, workspace_path: workspace_path}
```

The `ref` is the correlation ID. When the task replies or dies, the
orchestrator uses the ref to find the job and update authoritative state.

This earns the next abstraction:

```text
External workers need lifecycle tracking -> supervised tasks and monitors
```

## Reflection Questions

- Why is `:blocked` not the same as `:error`?
- Why should the runner not call `Queue.complete/2` directly?
- What would break if two workers tried to mutate queue state themselves?

## Checkpoint

Before moving on, you should be able to explain:

- how fake runner metadata forces different outcomes
- why crashes must be observed by the orchestrator
- why worker results are messages, not direct state writes
