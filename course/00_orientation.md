# 00 Orientation

## Learning Objective

Build the right mental model before reading the code: AgentRunway is not a web
app and not a generic queue. It is a tiny reliability system for long-running
agent work.

## Failure Story

In Node.js, Python, or Rails, it is tempting to begin with a database table,
a background job library, and some callbacks. That can work for ordinary jobs.

Agent orchestration stresses the design differently:

- runs are slow
- runs can crash
- runs may need human input
- external trackers can change state while work is running
- concurrency must be bounded
- each run needs an isolated workspace

The first failure is conceptual: if everything is "just a function call", no
single place owns the runtime truth.

## Code Reading Path

Read these files first:

- [`../README.md`](../README.md)
- [`../docs/failure_map.md`](../docs/failure_map.md)
- [`../lib/agent_queue/application.ex`](../lib/agent_queue/application.ex)
- [`../test/agent_queue/orchestrator_test.exs`](../test/agent_queue/orchestrator_test.exs)

Do not try to understand every line yet. Look for nouns:

- queue
- job
- issue
- runner
- tracker
- workspace
- orchestrator
- supervisor

## Walkthrough

`AgentQueue.Application` starts the OTP supervision tree:

```elixir
children = [
  {Registry, keys: :unique, name: AgentQueue.Registry},
  {Task.Supervisor, name: AgentQueue.WorkerSupervisor},
  {AgentQueue.QueueServer, name: AgentQueue.QueueServer}
]
```

This is already telling you the shape of the system. There is a registry for
names, a task supervisor for work, and a queue server that owns state.

The course then walks backward to the simplest version: a pure queue. That is
intentional. OTP makes more sense after you feel what breaks without it.

## Hands-On Lab

Run the current tests:

```bash
mix test
```

If Elixir is not installed:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace elixir:1.16 mix test
```

Expected result:

```text
11 tests, 0 failures
```

You may see an error log from the simulated crash test. That is expected. The
test intentionally raises inside a supervised task so the orchestrator can
convert a crash into failure state.

## Break It Exercise

Before changing code, answer this in a scratch note:

```text
If two agent runs finish at the same time, which module is allowed to decide
what happened to the queue?
```

Now inspect `AgentQueue.Orchestrator.handle_info/2` clauses. Look for how task
messages and `:DOWN` messages are handled.

## Full Walkthrough Solution

Only `AgentQueue.Orchestrator` should decide what happens to orchestration
state. Workers return messages. The fake tracker returns issues. The workspace
manager returns paths. But the orchestrator owns the transition from running to
completed, failed, retrying, or blocked.

This is the central OTP idea for the project:

```text
state owner + mailbox + explicit transitions
```

In Node.js terms, imagine avoiding shared global objects and instead routing
all state-changing events through one actor. That actor is not a thread. It is
a BEAM process with a mailbox.

## Reflection Questions

- What is the difference between "a job is running" and "we started a process"?
- Why is `running_tasks` separate from queue counts?
- What state would be dangerous to duplicate across modules?

## Checkpoint

Before moving on, you should be able to say:

> AgentRunway teaches OTP by making the orchestrator the only owner of runtime
> truth, then forcing failures through that owner.
