defmodule FileProcessor.Repo.Migrations.AddReportPathToExecutions do
  use Ecto.Migration

  def change do
    alter table(:executions) do
      add :report_path, :string
    end
  end
end
