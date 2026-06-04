defmodule AgentQueue.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: AgentQueue.Registry},
      {Task.Supervisor, name: AgentQueue.WorkerSupervisor},
      {AgentQueue.QueueServer, name: AgentQueue.QueueServer}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AgentQueue.Supervisor)
  end
end
