# Troubleshooting

## `mix: command not found`

Elixir is not installed locally.

Use Docker:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace elixir:1.16 mix test
```

Or install Elixir from:

```text
https://elixir-lang.org/install.html
```

## `erl: command not found`

Erlang/OTP is missing. Elixir requires Erlang. Use your OS package manager,
`asdf`, `mise`, or the official Elixir install instructions.

## Simulated Crash Logs During Tests

You may see a log like:

```text
Task ... terminating
** (RuntimeError) simulated agent crash
```

This is expected when running `test/agent_queue/orchestrator_test.exs`. The
test intentionally crashes a fake agent and verifies the orchestrator converts
that crash into failure state.

## Tests Are Flaky Around Sleeps

The course uses short sleeps to keep examples simple. If your machine is slow,
rerun the test. If you are extending the project, prefer polling assertions
like `assert_eventually/2` instead of fixed sleeps.

## `iex -S mix` Starts But Modules Are Missing

Make sure you are in the repository root:

```bash
pwd
ls mix.exs
```

Then restart:

```bash
iex -S mix
```

## Pattern Match Error

If you see a `MatchError`, inspect the return value.

For example, this assumes a job exists:

```elixir
{:ok, job, queue} = AgentQueue.Queue.claim_next(queue)
```

But an empty queue returns:

```elixir
{:empty, queue}
```

Pattern matching is not an exception handler. It is an assertion about shape.

## Process Already Started

If you start a named process twice in the same `iex` session, you may see an
error like:

```elixir
{:error, {:already_started, pid}}
```

Use a different name:

```elixir
AgentQueue.QueueServer.start_link(name: :lesson_queue_2)
```

Or restart `iex`.

## Docker Permission Denied

If Docker cannot connect to the daemon, either start Docker or install Elixir
locally. On Linux, your user may need access to the Docker socket.

## Useful Inspection Commands

Inside `iex`:

```elixir
Process.alive?(pid)
Process.info(pid, :message_queue_len)
AgentQueue.Orchestrator.stats(orchestrator)
AgentQueue.Orchestrator.snapshot(orchestrator)
```

For one test file:

```bash
mix test test/agent_queue/orchestrator_test.exs
```

For one line:

```bash
mix test test/agent_queue/orchestrator_test.exs:45
```
