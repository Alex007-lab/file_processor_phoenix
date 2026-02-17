defmodule FileProcessor.Executions do
  @moduledoc """
  The Executions context.
  """

  import Ecto.Query, warn: false
  alias FileProcessor.Repo
  alias FileProcessor.Executions.Execution

  @doc """
  Returns the list of executions.
  """
  def list_executions do
    Repo.all(from e in Execution, order_by: [desc: e.timestamp])
  end

  @doc """
  Returns the list of executions filtered by mode.
  Modes: "sequential", "parallel", "benchmark"
  """
  def list_executions_by_mode(mode) when mode in ["sequential", "parallel", "benchmark"] do
    Repo.all(from e in Execution,
      where: e.mode == ^mode,
      order_by: [desc: e.timestamp]
    )
  end

  @doc """
  Returns the list of executions filtered by date range.
  """
  def list_executions_by_date_range(start_date, end_date) do
    Repo.all(from e in Execution,
      where: e.timestamp >= ^start_date and e.timestamp <= ^end_date,
      order_by: [desc: e.timestamp]
    )
  end

  @doc """
  Returns statistics grouped by mode.
  """
  def get_statistics do
    sequential_count = Repo.aggregate(
      from(e in Execution, where: e.mode == "sequential"),
      :count,
      :id
    )

    parallel_count = Repo.aggregate(
      from(e in Execution, where: e.mode == "parallel"),
      :count,
      :id
    )

    benchmark_count = Repo.aggregate(
      from(e in Execution, where: e.mode == "benchmark"),
      :count,
      :id
    )

    # Manejar Decimal correctamente
    avg_time_result = Repo.one(
      from e in Execution,
      select: avg(e.total_time)
    )

    avg_time = case avg_time_result do
      %Decimal{} = decimal -> Decimal.round(decimal, 0) |> Decimal.to_integer()
      nil -> 0
      integer when is_integer(integer) -> integer
      float when is_float(float) -> round(float)
      _ -> 0
    end

    %{
      total: sequential_count + parallel_count + benchmark_count,
      sequential: sequential_count,
      parallel: parallel_count,
      benchmark: benchmark_count,
      avg_time: avg_time
    }
  end

  @doc """
  Gets a single execution.
  Raises `Ecto.NoResultsError` if the Execution does not exist.
  """
  def get_execution!(id), do: Repo.get!(Execution, id)

  @doc """
  Creates a execution.
  """
  def create_execution(attrs) do
    %Execution{}
    |> Execution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a execution.
  """
  def update_execution(%Execution{} = execution, attrs) do
    execution
    |> Execution.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a execution.
  """
  def delete_execution(%Execution{} = execution) do
    Repo.delete(execution)
  end

  @doc """
  Deletes all executions.
  """
  def delete_all_executions do
    Repo.delete_all(Execution)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking execution changes.
  """
  def change_execution(%Execution{} = execution, attrs \\ %{}) do
    Execution.changeset(execution, attrs)
  end
end
