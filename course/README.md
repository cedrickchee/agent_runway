# AgentRunway Course

This is a self-guided, hands-on course for learning Elixir/OTP through
failure-driven agent orchestration.

The project is already implemented. Your job as the learner is to read it,
run it, break it, repair your mental model, and then map the result to
Symphony-style AI agent infrastructure.

## Who This Is For

This course assumes you are already comfortable programming in systems like
JavaScript/Node.js, Python, or Ruby on Rails. It does not spend much time on
basic programming concepts. Instead, it focuses on what is different about
Elixir and OTP:

- immutable data instead of object mutation
- pattern matching instead of defensive conditionals
- processes as state owners
- mailboxes instead of shared mutable state
- supervision instead of ad hoc restart code
- explicit failure states for long-running agent work

## Prerequisites

Install Elixir and Erlang/OTP:

```bash
elixir --version
mix --version
```

If Elixir is not installed locally, you can run checks with Docker:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace elixir:1.16 mix test
```

The local project has no third-party dependencies.

## Suggested Four-Day Schedule

Day 1:

- [00 Orientation](00_orientation.md)
- [01 Pure Queue](01_pure_queue.md)

Day 2:

- [02 Queue Server](02_queue_server.md)
- [03 Workers And Failures](03_workers_and_failures.md)

Day 3:

- [04 Supervision And Backpressure](04_supervision_and_backpressure.md)
- [05 Orchestrator](05_orchestrator.md)

Day 4:

- [06 Boundaries And Workspaces](06_boundaries_and_workspaces.md)
- [07 Symphony Mapping](07_symphony_mapping.md)
- [Capstone](capstone.md)

Reference material:

- [Glossary](glossary.md)
- [Troubleshooting](troubleshooting.md)
- [Project Failure Map](../docs/failure_map.md)

## How To Work Through A Lesson

Each lesson follows the same loop:

1. Read the failure story.
2. Read the listed source files.
3. Run the listed tests.
4. Try the `iex` lab.
5. Do the break-it exercise.
6. Read the full walkthrough solution.
7. Write down the Symphony connection in your own words.

The important habit is to resist memorizing OTP names. Every abstraction should
feel like an answer to a specific operational failure.

## Core Commands

Run the full suite:

```bash
mix test
```

Run one test file:

```bash
mix test test/agent_queue/queue_test.exs
```

Start an interactive shell:

```bash
iex -S mix
```

Format check:

```bash
mix format --check-formatted
```

Docker equivalents:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace elixir:1.16 mix test
docker run --rm -v "$PWD":/workspace -w /workspace elixir:1.16 mix format --check-formatted
```

## Completion Criteria

You are done when you can explain these without reading from the source:

- why a pure queue is not enough
- why one process should own orchestration state
- why agent runs must leave the queue process
- how crashes become data in the orchestrator
- why bounded concurrency is part of correctness
- why workspaces and external adapters are failure boundaries
- how AgentRunway maps to Symphony
