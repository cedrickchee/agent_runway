defmodule AgentQueue.WorkspaceManager do
  @moduledoc """
  Creates one deterministic workspace directory per issue.
  """

  alias AgentQueue.Issue

  def ensure_workspace(%Issue{} = issue, root) do
    path = Path.join(root, sanitize(issue.identifier))

    with :ok <- File.mkdir_p(path) do
      {:ok, path}
    end
  end

  def sanitize(identifier) do
    identifier
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9._-]/, "_")
  end
end
