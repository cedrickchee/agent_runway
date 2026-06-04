import Config

config :agent_queue,
  workspace_root: Path.join(System.tmp_dir!(), "agent_queue_workspaces"),
  max_concurrent: 2,
  poll_interval_ms: 1_000,
  retry_backoff_ms: 100,
  max_attempts: 3
