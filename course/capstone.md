# Capstone

## Goal

Add one new failure mode or adapter boundary to AgentRunway and explain the OTP
design in writing.

This capstone is intentionally small. The value is not the amount of code. The
value is proving that you can reason from failure to abstraction.

## Choose One Track

Track A: Runner Timeout

- Add a runner mode like `%{runner: :timeout}`.
- Make it sleep longer than an orchestrator timeout.
- Add timeout handling that marks the job retrying or blocked.
- Explain why timeout policy belongs in the orchestrator.

Track B: Realistic Tracker Failure

- Add a fake tracker mode that returns `{:error, :rate_limited}`.
- Record a tracker failure event.
- Do not crash the orchestrator.
- Explain why polling failure is not the same as job failure.

Track C: Workspace Failure

- Add a workspace manager failure case for invalid roots.
- Ensure agent work does not start when workspace setup fails.
- Map the failure into retry or failed state.
- Explain why workspace setup is part of the agent-run boundary.

Recommended track: Track B. It requires the smallest code change and most
directly reinforces external-boundary thinking.

## Required Deliverables

1. One failing test first.
2. Minimal implementation to pass the test.
3. A short note in `docs/failure_map.md` or a new scratch file explaining:
   - what broke
   - what abstraction handled it
   - why the orchestrator owns the policy
   - how the idea maps to Symphony

## Suggested Test Shape

For Track B, write a test with this intent:

```elixir
test "tracker polling failures are recorded without crashing the orchestrator" do
  # Arrange a tracker that returns {:error, :rate_limited}
  # Start the orchestrator
  # Poll
  # Assert the process is alive
  # Assert an event records the tracker failure
end
```

Do not overbuild. Avoid real HTTP calls. Keep the boundary fake and
deterministic.

## Full Walkthrough Solution

The solution pattern is:

1. Create a deterministic failure.
2. Route the failure through a boundary return value.
3. Let the orchestrator classify it.
4. Assert the orchestrator remains alive.
5. Assert the event or queue state changed.

For Track B, the important distinction is:

```text
tracker polling failed != an issue failed
```

If Linear is rate-limited, no job should be marked failed. The system should
record the event and try again later. This is exactly the kind of distinction
agent infrastructure must preserve.

## Reflection Prompt

Write five sentences:

```text
The failure I introduced was ...
The first naive fix would be ...
That fix is not enough because ...
The OTP-shaped solution is ...
This maps to Symphony because ...
```

## Completion Check

You have completed the capstone when:

- `mix test` passes
- your failure is deterministic
- the orchestrator does not crash
- your written explanation connects code to architecture
