defmodule AgentQueue.Job do
  @moduledoc """
  Work item used by the early queue phases.

  In the mini-Symphony phases, the `payload` is usually an `AgentQueue.Issue`.
  """

  @enforce_keys [:id, :payload, :created_at, :updated_at]
  defstruct [
    :id,
    :payload,
    :created_at,
    :updated_at,
    :retry_at,
    :last_error,
    status: :queued,
    attempts: 0
  ]

  @type status :: :queued | :running | :retrying | :completed | :failed | :blocked

  @type t :: %__MODULE__{
          id: term(),
          payload: term(),
          status: status(),
          attempts: non_neg_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          retry_at: integer() | nil,
          last_error: term() | nil
        }

  def new(payload, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &AgentQueue.Clock.utc_now/0)

    %__MODULE__{
      id: Keyword.get_lazy(opts, :id, fn -> System.unique_integer([:positive, :monotonic]) end),
      payload: payload,
      created_at: now,
      updated_at: now
    }
  end

  def transition(%__MODULE__{} = job, status, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &AgentQueue.Clock.utc_now/0)
    attrs = opts |> Keyword.delete(:now) |> Map.new()

    job
    |> Map.merge(attrs)
    |> Map.put(:status, status)
    |> Map.put(:updated_at, now)
  end
end
