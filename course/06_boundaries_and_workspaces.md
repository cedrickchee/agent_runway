# 06 Boundaries And Workspaces

## Learning Objective

Understand why external systems are represented as boundaries: issue trackers,
workflow rendering, workspace creation, and Codex-style agent execution all
fail in different ways.

## Failure Story

The orchestrator can own state, but it cannot make external systems reliable.

The failure:

```text
External systems are slow, partial, and fallible
```

The answer is explicit boundaries with small return shapes.

## Code Reading Path

Read:

- [`../lib/agent_queue/fake_tracker.ex`](../lib/agent_queue/fake_tracker.ex)
- [`../lib/agent_queue/workspace_manager.ex`](../lib/agent_queue/workspace_manager.ex)
- [`../lib/agent_queue/workflow.ex`](../lib/agent_queue/workflow.ex)
- [`../lib/agent_queue/agent_runner.ex`](../lib/agent_queue/agent_runner.ex)
- [`../lib/agent_queue/orchestrator.ex`](../lib/agent_queue/orchestrator.ex)

Focus on:

- `FakeTracker.fetch_candidates/2`
- `FakeTracker.fetch_state/2`
- `WorkspaceManager.ensure_workspace/2`
- `Workflow.render_prompt/1`
- `AgentRunner.run/2`

## Walkthrough

The fake tracker stands in for Linear:

```elixir
FakeTracker.fetch_candidates(tracker)
FakeTracker.fetch_state(tracker, issue_id)
```

The workspace manager stands in for per-issue repository setup:

```elixir
WorkspaceManager.ensure_workspace(issue, root)
```

The workflow renderer stands in for prompt construction:

```elixir
Workflow.render_prompt(issue)
```

The runner stands in for Codex App Server session lifecycle:

```elixir
AgentRunner.run(job, workspace_path: path)
```

Each boundary returns either useful data or an explicit failure shape. That is
what lets the orchestrator stay in charge.

## Hands-On Lab

In `iex -S mix`:

```elixir
issue = %AgentQueue.Issue{
  id: "AGENT-9",
  identifier: "AGENT-9",
  title: "Create workspace",
  description: "Boundary exercise",
  state: "Ready",
  metadata: %{runner: :success}
}

AgentQueue.WorkspaceManager.ensure_workspace(issue, "/tmp/agent-runway-course")
AgentQueue.Workflow.render_prompt(issue)
```

Then run the full orchestrated path:

```elixir
{:ok, tracker} = AgentQueue.FakeTracker.start_link(issues: [issue])
{:ok, orchestrator} = AgentQueue.Orchestrator.start_link(tracker_ref: tracker)
AgentQueue.Orchestrator.poll(orchestrator)
Process.sleep(50)
AgentQueue.Orchestrator.snapshot(orchestrator).queue.completed
```

Inspect the completed result and workspace path in the event log.

## Break It Exercise

Imagine replacing `FakeTracker` with a real Linear adapter.

List three things that can fail before an agent ever starts.

Then inspect `poll_tracker/1` and `start_agent/2`. Where would those failures
be converted into events or queue state?

## Full Walkthrough Solution

A real Linear adapter can fail because:

- credentials are missing
- the API times out
- returned issue data is malformed
- rate limits are hit
- an issue disappears or changes state between polling and dispatch

A real Codex runner can fail because:

- workspace setup fails
- the repository cannot be prepared
- the app-server is unavailable
- the agent blocks on approval or human input
- the process crashes

AgentRunway keeps those failures at boundaries. The orchestrator receives
small outcomes and maps them into runtime state:

```text
external failure -> boundary return value -> orchestrator event/state
```

This design is intentionally boring. Boring boundaries make failure handling
inspectable.

## Reflection Questions

- Which boundary should know about API credentials?
- Which boundary should know about retry policy?
- Why should workspace paths be created before starting the runner?

## Checkpoint

Before moving on, you should be able to explain:

- why fake integrations are useful before real ones
- how per-issue workspaces isolate agent runs
- how prompt rendering maps to a workflow loader
- why external calls should not directly mutate orchestration state
