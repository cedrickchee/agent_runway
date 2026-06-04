# Agent Queue

Failure-driven Elixir/OTP learning project for understanding Symphony-style AI
agent orchestration.

The project starts as a pure job queue and grows into a tiny orchestrator with
supervised workers, retry policy, fake Linear polling, fake Codex runs, and
per-issue workspaces.

## Install Elixir

This workspace does not currently have `elixir`, `erl`, or `mix` installed.
Install Elixir from the official guide first:

<https://elixir-lang.org/install.html>

After installation:

```bash
mix test
iex -S mix
```

## Learning Order

1. Read `lib/agent_queue/queue.ex` and `test/agent_queue/queue_test.exs`.
2. Read `lib/agent_queue/queue_server.ex` and `test/agent_queue/queue_server_test.exs`.
3. Read `lib/agent_queue/agent_runner.ex`.
4. Read `lib/agent_queue/orchestrator.ex` and `test/agent_queue/orchestrator_test.exs`.
5. Read `docs/failure_map.md`.
6. Compare the shape to Symphony's spec:
   <https://github.com/openai/symphony/blob/main/SPEC.md>

## Manual Session

Once Elixir is installed:

```elixir
{:ok, tracker} =
  AgentQueue.FakeTracker.start_link(
    issues: [
      %AgentQueue.Issue{
        id: "AGENT-1",
        identifier: "AGENT-1",
        title: "Try a fake Codex run",
        description: "This is a synthetic issue.",
        state: "Ready",
        metadata: %{runner: :success}
      }
    ]
  )

{:ok, orchestrator} =
  AgentQueue.Orchestrator.start_link(
    tracker_ref: tracker,
    max_concurrent: 1,
    retry_backoff_ms: 100
  )

AgentQueue.Orchestrator.poll(orchestrator)
AgentQueue.Orchestrator.stats(orchestrator)
AgentQueue.Orchestrator.snapshot(orchestrator)
```

Try changing `metadata` to `%{runner: :fail}`, `%{runner: :crash}`, or
`%{runner: :block}` and observe how the orchestrator state changes.

## Project Shape

- `AgentQueue.Queue`: pure data state machine.
- `AgentQueue.QueueServer`: the queue becomes one actor that owns state.
- `AgentQueue.AgentRunner`: fake Codex runner boundary.
- `AgentQueue.FakeTracker`: fake Linear tracker boundary.
- `AgentQueue.WorkspaceManager`: one workspace per issue.
- `AgentQueue.Orchestrator`: Symphony-shaped runtime owner.

The project intentionally favors clarity over production completeness. Durable
storage, real Linear API calls, real Codex App Server integration, dashboards,
and distributed execution are the next steps after the OTP shape is clear.
