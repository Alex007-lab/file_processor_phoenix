defmodule FileProcessor.Executions.Execution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "executions" do
    field :timestamp, :utc_datetime
    field :files, :string
    field :mode, :string
    field :total_time, :integer
    field :result, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [:timestamp, :files, :mode, :total_time, :result])
    |> validate_required([:timestamp, :files, :mode, :total_time, :result])
  end
end
