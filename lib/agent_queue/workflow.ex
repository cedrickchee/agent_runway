defmodule AgentQueue.Workflow do
  @moduledoc """
  Tiny prompt renderer standing in for Symphony's workflow contract.
  """

  alias AgentQueue.Issue

  def render_prompt(%Issue{} = issue) do
    """
    You are working on #{issue.identifier}.

    Title: #{issue.title}
    State: #{issue.state}

    #{issue.description || "No description provided."}
    """
    |> String.trim()
  end
end
