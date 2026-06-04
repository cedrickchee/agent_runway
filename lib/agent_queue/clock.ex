defmodule AgentQueue.Clock do
  @moduledoc """
  Small clock wrapper so tests and pure functions can pass explicit times.
  """

  def now_ms do
    System.monotonic_time(:millisecond)
  end

  def utc_now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end
end
