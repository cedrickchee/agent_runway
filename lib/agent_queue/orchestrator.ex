defmodule AgentQueue.Orchestrator do
  @moduledoc """
  Phase 5: the queue becomes a Symphony-shaped orchestrator.

  The orchestrator owns authoritative runtime state: queued issues, running
  tasks, retry entries, blocked work, and runtime events.
  """

  use GenServer

  alias AgentQueue.{AgentRunner, FakeTracker, Job, Queue, WorkspaceManager}

  defstruct queue: Queue.new(),
            running: %{},
            claimed: MapSet.new(),
            seen_issue_ids: MapSet.new(),
            events: [],
            tracker: nil,
            tracker_ref: nil,
            runner: AgentRunner,
            task_supervisor: AgentQueue.WorkerSupervisor,
            workspace_root: nil,
            max_concurrent: 2,
            poll_interval_ms: 1_000,
            retry_backoff_ms: 100,
            max_attempts: 3,
            auto_poll?: false,
            terminal_states: ["Done", "Closed", "Cancelled", "Duplicate"]

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  def enqueue(server, issue) do
    GenServer.call(server, {:enqueue, issue})
  end

  def poll(server) do
    GenServer.call(server, :poll)
  end

  def dispatch(server) do
    GenServer.call(server, :dispatch)
  end

  def snapshot(server) do
    GenServer.call(server, :snapshot)
  end

  def stats(server) do
    GenServer.call(server, :stats)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      tracker: Keyword.get(opts, :tracker, FakeTracker),
      tracker_ref: Keyword.get(opts, :tracker_ref),
      runner: Keyword.get(opts, :runner, AgentRunner),
      task_supervisor: Keyword.get(opts, :task_supervisor, AgentQueue.WorkerSupervisor),
      workspace_root: Keyword.get(opts, :workspace_root, default_workspace_root()),
      max_concurrent: Keyword.get(opts, :max_concurrent, default(:max_concurrent)),
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, default(:poll_interval_ms)),
      retry_backoff_ms: Keyword.get(opts, :retry_backoff_ms, default(:retry_backoff_ms)),
      max_attempts: Keyword.get(opts, :max_attempts, default(:max_attempts)),
      auto_poll?: Keyword.get(opts, :auto_poll?, false)
    }

    if state.auto_poll? do
      Process.send_after(self(), :poll, 0)
    end

    {:ok, record(state, :started, %{})}
  end

  @impl true
  def handle_call({:enqueue, issue}, _from, state) do
    {job, state} = enqueue_issue(state, issue)
    {:reply, {:ok, job}, dispatch_until_full(state)}
  end

  def handle_call(:poll, _from, state) do
    state =
      state
      |> poll_tracker()
      |> reconcile_running()
      |> dispatch_until_full()

    {:reply, :ok, state}
  end

  def handle_call(:dispatch, _from, state) do
    {:reply, :ok, dispatch_until_full(state)}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:stats, _from, state) do
    stats =
      state.queue
      |> Queue.stats()
      |> Map.merge(%{
        running_tasks: map_size(state.running),
        claimed: MapSet.size(state.claimed),
        seen_issues: MapSet.size(state.seen_issue_ids)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state =
      state
      |> poll_tracker()
      |> reconcile_running()
      |> dispatch_until_full()

    if state.auto_poll? do
      Process.send_after(self(), :poll, state.poll_interval_ms)
    end

    {:noreply, state}
  end

  def handle_info(:retry_due, state) do
    state = %{state | queue: Queue.retry_due(state.queue)}
    {:noreply, dispatch_until_full(record(state, :retry_due, %{}))}
  end

  def handle_info({ref, {:ok, result}}, state) when is_reference(ref) do
    {entry, state} = pop_running_by_ref(state, ref)

    state =
      if entry do
        Process.demonitor(ref, [:flush])

        state
        |> complete_entry(entry)
        |> record(:agent_succeeded, %{job_id: entry.job.id, result: result})
        |> dispatch_until_full()
      else
        state
      end

    {:noreply, state}
  end

  def handle_info({ref, {:error, reason}}, state) when is_reference(ref) do
    {entry, state} = pop_running_by_ref(state, ref)

    state =
      if entry do
        Process.demonitor(ref, [:flush])

        state
        |> fail_entry(entry, reason)
        |> record(:agent_failed, %{job_id: entry.job.id, reason: reason})
        |> dispatch_until_full()
      else
        state
      end

    {:noreply, state}
  end

  def handle_info({ref, {:blocked, reason}}, state) when is_reference(ref) do
    {entry, state} = pop_running_by_ref(state, ref)

    state =
      if entry do
        Process.demonitor(ref, [:flush])

        state
        |> block_entry(entry, reason)
        |> record(:agent_blocked, %{job_id: entry.job.id, reason: reason})
        |> dispatch_until_full()
      else
        state
      end

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case pop_running_by_ref(state, ref) do
      {nil, state} ->
        {:noreply, state}

      {entry, state} ->
        state =
          state
          |> fail_entry(entry, {:crash, reason})
          |> record(:agent_crashed, %{job_id: entry.job.id, reason: reason})
          |> dispatch_until_full()

        {:noreply, state}
    end
  end

  defp enqueue_issue(state, issue) do
    id = issue.id
    {job, queue} = Queue.enqueue(state.queue, issue, id: id)

    state =
      %{state | queue: queue, seen_issue_ids: MapSet.put(state.seen_issue_ids, id)}
      |> record(:issue_enqueued, %{issue_id: id})

    {job, state}
  end

  defp poll_tracker(%{tracker_ref: nil} = state), do: state

  defp poll_tracker(state) do
    tracker = state.tracker

    case tracker.fetch_candidates(state.tracker_ref) do
      {:ok, issues} ->
        Enum.reduce(issues, state, fn issue, acc ->
          if MapSet.member?(acc.seen_issue_ids, issue.id) or MapSet.member?(acc.claimed, issue.id) do
            acc
          else
            {_job, acc} = enqueue_issue(acc, issue)
            acc
          end
        end)

      {:error, reason} ->
        record(state, :tracker_failed, %{reason: reason})
    end
  end

  defp reconcile_running(%{tracker_ref: nil} = state), do: state

  defp reconcile_running(state) do
    Enum.reduce(state.running, state, fn {job_id, entry}, acc ->
      tracker = acc.tracker

      case tracker.fetch_state(acc.tracker_ref, job_id) do
        {:ok, state_name} ->
          if terminal_state?(acc, state_name) do
            stop_running(entry)

            acc
            |> block_entry(entry, {:terminal_issue_state, state_name})
            |> release_running(entry)
            |> record(:issue_became_terminal, %{job_id: job_id, state: state_name})
          else
            acc
          end

        {:error, reason} ->
          record(acc, :reconcile_failed, %{job_id: job_id, reason: reason})
      end
    end)
  end

  defp dispatch_until_full(state) do
    if map_size(state.running) >= state.max_concurrent do
      state
    else
      case Queue.claim_next(state.queue) do
        {:empty, queue} ->
          %{state | queue: queue}

        {:ok, %Job{} = job, queue} ->
          state = %{state | queue: queue}

          case start_agent(state, job) do
            {:ok, entry, state} ->
              state
              |> put_running(entry)
              |> record(:agent_started, %{job_id: job.id, pid: entry.pid})
              |> dispatch_until_full()

            {:error, reason, state} ->
              state
              |> fail_claimed_job(job, reason)
              |> record(:agent_start_failed, %{job_id: job.id, reason: reason})
              |> dispatch_until_full()
          end
      end
    end
  end

  defp start_agent(state, %Job{} = job) do
    runner = state.runner

    with {:ok, workspace_path} <-
           WorkspaceManager.ensure_workspace(job.payload, state.workspace_root) do
      task =
        Task.Supervisor.async_nolink(state.task_supervisor, fn ->
          runner.run(job, workspace_path: workspace_path)
        end)

      entry = %{job: job, pid: task.pid, ref: task.ref, workspace_path: workspace_path}
      {:ok, entry, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp put_running(state, entry) do
    %{
      state
      | running: Map.put(state.running, entry.job.id, entry),
        claimed: MapSet.put(state.claimed, entry.job.id)
    }
  end

  defp pop_running_by_ref(state, ref) do
    case Enum.find(state.running, fn {_id, entry} -> entry.ref == ref end) do
      nil ->
        {nil, state}

      {job_id, entry} ->
        {entry, release_running(state, entry, job_id)}
    end
  end

  defp release_running(state, entry, job_id \\ nil) do
    job_id = job_id || entry.job.id

    %{
      state
      | running: Map.delete(state.running, job_id),
        claimed: MapSet.delete(state.claimed, job_id)
    }
  end

  defp complete_entry(state, nil), do: state

  defp complete_entry(state, entry) do
    {:ok, _job, queue} = Queue.complete(state.queue, entry.job.id)
    %{state | queue: queue}
  end

  defp fail_entry(state, nil, _reason), do: state

  defp fail_entry(state, entry, reason) do
    fail_claimed_job(state, entry.job, reason)
  end

  defp fail_claimed_job(state, job, reason) do
    case Queue.fail(state.queue, job.id, reason,
           max_attempts: state.max_attempts,
           backoff_ms: state.retry_backoff_ms
         ) do
      {:retrying, retrying, queue} ->
        schedule_retry(retrying)
        %{state | queue: queue}

      {:failed, _failed, queue} ->
        %{state | queue: queue}

      {:error, _reason, queue} ->
        %{state | queue: queue}
    end
  end

  defp block_entry(state, nil, _reason), do: state

  defp block_entry(state, entry, reason) do
    case Queue.block(state.queue, entry.job.id, reason) do
      {:blocked, _job, queue} -> %{state | queue: queue}
      {:error, _reason, queue} -> %{state | queue: queue}
    end
  end

  defp stop_running(entry) do
    Process.demonitor(entry.ref, [:flush])
    Process.exit(entry.pid, :kill)
  end

  defp schedule_retry(%{retry_at: retry_at}) when is_integer(retry_at) do
    delay = max(retry_at - AgentQueue.Clock.now_ms(), 0)
    Process.send_after(self(), :retry_due, delay)
  end

  defp terminal_state?(state, state_name) do
    normalized = String.downcase(to_string(state_name))

    Enum.any?(state.terminal_states, fn terminal ->
      String.downcase(to_string(terminal)) == normalized
    end)
  end

  defp record(state, event, payload) do
    entry = %{event: event, payload: payload, at: AgentQueue.Clock.utc_now()}
    %{state | events: [entry | state.events]}
  end

  defp default(key), do: Application.fetch_env!(:agent_queue, key)

  defp default_workspace_root do
    Application.fetch_env!(:agent_queue, :workspace_root)
  end
end
