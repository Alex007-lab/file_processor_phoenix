# priv/repo/migrations/20260217123456_add_status_to_executions.exs
defmodule FileProcessor.Repo.Migrations.AddStatusToExecutions do
  use Ecto.Migration

  def change do
    alter table(:executions) do
      add :status, :string, default: "success"
    end
  end
end
