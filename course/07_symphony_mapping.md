# 07 Symphony Mapping

## Learning Objective

Map AgentRunway's small OTP system to Symphony's larger agent orchestration
architecture.

## Failure Story

Reading a mature orchestration system too early can feel like reading a list
of arbitrary components.

After AgentRunway, the components should feel earned:

```text
each module exists because a smaller design failed
```

## Code Reading Path

Read:

- [`../docs/failure_map.md`](../docs/failure_map.md)
- [`../lib/agent_queue/orchestrator.ex`](../lib/agent_queue/orchestrator.ex)
- [`../lib/agent_queue/fake_tracker.ex`](../lib/agent_queue/fake_tracker.ex)
- [`../lib/agent_queue/workspace_manager.ex`](../lib/agent_queue/workspace_manager.ex)
- [`../lib/agent_queue/agent_runner.ex`](../lib/agent_queue/agent_runner.ex)

Then read Symphony's public spec:

- <https://github.com/openai/symphony/blob/main/SPEC.md>

## Walkthrough

AgentRunway maps to Symphony like this:

| AgentRunway | Symphony-shaped concept |
| --- | --- |
| `AgentQueue.Issue` | normalized tracker issue |
| `AgentQueue.FakeTracker` | issue tracker client |
| `AgentQueue.Workflow` | workflow loader and prompt renderer |
| `AgentQueue.WorkspaceManager` | workspace manager |
| `AgentQueue.AgentRunner` | Codex App Server runner |
| `AgentQueue.Orchestrator` | authoritative runtime orchestrator |
| `state.events` | observability stream |
| `max_concurrent` | bounded agent dispatch |
| `retrying` bucket | retry/backoff state |
| `blocked` bucket | human/operator intervention state |

The names differ, but the pressure is the same: long-running AI agents need a
runtime that can launch, observe, classify, retry, stop, and explain work.

## Hands-On Lab

Open `AgentQueue.Orchestrator` and write a short note for each public function:

```text
enqueue/2:
poll/1:
dispatch/1:
snapshot/1:
stats/1:
```

Now rewrite each note using Symphony vocabulary:

```text
poll/1: ask the issue tracker for eligible work, reconcile running work,
then dispatch while concurrency is available.
```

## Break It Exercise

Pick one Symphony component from the spec and ask:

```text
What failure would force this component to exist?
```

Examples:

- Why have a workspace manager?
- Why have an issue tracker abstraction?
- Why have an orchestrator instead of independent workers?
- Why keep runtime state explicit?

## Full Walkthrough Solution

Use this mapping:

- Workspace manager exists because agent runs need isolated filesystem state.
- Issue tracker abstraction exists because Linear/GitHub-style systems are
  external, fallible, and domain-specific.
- Orchestrator exists because workers cannot each own global truth.
- Runtime state exists because "the process is alive" is not enough to explain
  whether work is queued, running, retrying, blocked, completed, or failed.
- Observability exists because long-running agents need an audit trail.

The Symphony reading strategy is:

1. Identify the state owner.
2. Identify the external boundaries.
3. Identify how work is claimed.
4. Identify how work is observed.
5. Identify how failure becomes state.

## Reflection Questions

- Which AgentRunway simplification would fail first at real scale?
- Which Symphony component most directly maps to OTP supervision?
- What data would need to become durable before production use?

## Checkpoint

Before moving on, you should be able to explain:

- how AgentRunway prepares you to read Symphony
- which AgentRunway modules are intentionally fake boundaries
- why OTP fits AI-agent orchestration
- why process supervision and domain retry policy are different things
