defmodule AgentQueue.Issue do
  @moduledoc """
  Normalized issue shape used once the queue becomes a mini-orchestrator.
  """

  @enforce_keys [:id, :identifier, :title, :state]
  defstruct [
    :id,
    :identifier,
    :title,
    :description,
    :priority,
    :url,
    state: "Ready",
    labels: [],
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          identifier: String.t(),
          title: String.t(),
          description: String.t() | nil,
          priority: integer() | nil,
          url: String.t() | nil,
          state: String.t(),
          labels: [String.t()],
          metadata: map()
        }

  def terminal?(
        %__MODULE__{state: state},
        terminal_states \\ ["Done", "Closed", "Cancelled", "Duplicate"]
      ) do
    normalized = String.downcase(to_string(state))

    Enum.any?(terminal_states, fn terminal ->
      String.downcase(to_string(terminal)) == normalized
    end)
  end
end
