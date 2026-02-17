# lib/file_processor/executions/execution.ex

defmodule FileProcessor.Executions.Execution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "executions" do
    field :timestamp, :utc_datetime
    field :files, :string
    field :mode, :string
    field :total_time, :integer
    field :result, :string
    field :status, :string  # ← NUEVO CAMPO

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [:timestamp, :files, :mode, :total_time, :result, :status])
    |> validate_required([:timestamp, :files, :mode, :total_time, :result])
    |> validate_inclusion(:status, ["success", "partial", "error"])
  end
end
