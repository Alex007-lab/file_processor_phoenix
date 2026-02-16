defmodule FileProcessor.Repo.Migrations.CreateExecutions do
  use Ecto.Migration

  def change do
    create table(:executions) do
      add :timestamp, :utc_datetime
      add :files, :text
      add :mode, :string
      add :total_time, :integer
      add :result, :text

      timestamps(type: :utc_datetime)
    end
  end
end
