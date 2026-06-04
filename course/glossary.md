# Glossary

## Actor

A process that owns state and receives messages. In this course,
`AgentQueue.QueueServer` and `AgentQueue.Orchestrator` are actor-shaped state
owners.

JS comparison: closer to a dedicated event-loop object with a private inbox
than to a class instance shared by many callers.

## BEAM

The Erlang virtual machine that runs Erlang and Elixir code. It provides
lightweight processes, scheduling, message passing, and fault-tolerance
primitives.

## GenServer

An OTP behavior for writing a process that owns state and handles messages in a
standard shape. AgentRunway uses it for `QueueServer` and `Orchestrator`.

## Mailbox

Each BEAM process has a mailbox. Messages arrive there and are processed by the
receiving process.

Node comparison: not a shared callback queue for the whole runtime; each
process has its own mailbox.

## Supervision Tree

A hierarchy of processes that defines how child processes are started and
restarted. AgentRunway starts `Task.Supervisor` and `QueueServer` from
`AgentQueue.Application`.

## Task.Supervisor

An OTP supervisor for short-lived tasks. AgentRunway uses
`AgentQueue.WorkerSupervisor` to run fake agent sessions outside the
orchestrator process.

## Link

A relationship where process exits propagate. Useful when processes should
share fate.

## Monitor

A relationship where one process receives a `:DOWN` message when another
process exits. Useful when the observer should learn about failure without
crashing.

## `async_nolink`

Starts a supervised task without linking it to the caller. AgentRunway uses it
so a crashing worker does not kill the orchestrator.

## Backpressure

Refusing or delaying new work because the system is already at capacity.
AgentRunway models this with `max_concurrent`.

## Retry Policy

Domain logic that decides whether failed work should run again later.
Supervision can restart processes, but retry policy decides what happens to the
job.

## Blocked Work

Work that should not retry automatically. In agent systems this often means
human approval, missing context, external conflict, or operator intervention is
needed.

## Reconciliation

Comparing local runtime state with external truth and deciding what to do.
AgentRunway reconciles running work against tracker state.

## Boundary

A module that hides an external system or unstable side effect behind a small
interface. `FakeTracker`, `WorkspaceManager`, `Workflow`, and `AgentRunner` are
boundaries.

## Workspace

A per-issue filesystem location where agent work can happen in isolation.

## Symphony

OpenAI's Codex orchestration system. In this course, Symphony is the larger
architecture you are preparing to understand by first building and breaking
AgentRunway.
