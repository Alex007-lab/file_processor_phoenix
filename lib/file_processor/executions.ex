defmodule FileProcessor.Executions do
  @moduledoc """
  The Executions context.
  """

  import Ecto.Query, warn: false
  alias FileProcessor.Repo

  alias FileProcessor.Executions.Execution

  @doc """
  Returns the list of executions.

  ## Examples

      iex> list_executions()
      [%Execution{}, ...]

  """
  def list_executions do
    Repo.all(Execution)
  end

  @doc """
  Gets a single execution.

  Raises `Ecto.NoResultsError` if the Execution does not exist.

  ## Examples

      iex> get_execution!(123)
      %Execution{}

      iex> get_execution!(456)
      ** (Ecto.NoResultsError)

  """
  def get_execution!(id), do: Repo.get!(Execution, id)

  @doc """
  Creates a execution.

  ## Examples

      iex> create_execution(%{field: value})
      {:ok, %Execution{}}

      iex> create_execution(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_execution(attrs) do
    %Execution{}
    |> Execution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a execution.

  ## Examples

      iex> update_execution(execution, %{field: new_value})
      {:ok, %Execution{}}

      iex> update_execution(execution, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_execution(%Execution{} = execution, attrs) do
    execution
    |> Execution.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a execution.

  ## Examples

      iex> delete_execution(execution)
      {:ok, %Execution{}}

      iex> delete_execution(execution)
      {:error, %Ecto.Changeset{}}

  """
  def delete_execution(%Execution{} = execution) do
    Repo.delete(execution)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking execution changes.

  ## Examples

      iex> change_execution(execution)
      %Ecto.Changeset{data: %Execution{}}

  """
  def change_execution(%Execution{} = execution, attrs \\ %{}) do
    Execution.changeset(execution, attrs)
  end
end
