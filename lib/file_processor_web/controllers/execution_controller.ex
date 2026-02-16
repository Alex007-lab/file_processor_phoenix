defmodule FileProcessorWeb.ExecutionController do
  use FileProcessorWeb, :controller

  alias FileProcessor.Executions
  alias FileProcessor.Executions.Execution

  def index(conn, _params) do
    executions = Executions.list_executions()
    render(conn, :index, executions: executions)
  end

  def new(conn, _params) do
    changeset = Executions.change_execution(%Execution{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"execution" => execution_params}) do
    case Executions.create_execution(execution_params) do
      {:ok, execution} ->
        conn
        |> put_flash(:info, "Execution created successfully.")
        |> redirect(to: ~p"/executions/#{execution}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)
    render(conn, :show, execution: execution)
  end

  def edit(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)
    changeset = Executions.change_execution(execution)
    render(conn, :edit, execution: execution, changeset: changeset)
  end

  def update(conn, %{"id" => id, "execution" => execution_params}) do
    execution = Executions.get_execution!(id)

    case Executions.update_execution(execution, execution_params) do
      {:ok, execution} ->
        conn
        |> put_flash(:info, "Execution updated successfully.")
        |> redirect(to: ~p"/executions/#{execution}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, execution: execution, changeset: changeset)
    end
  end

  def download(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)

    send_download(conn, {:binary, execution.result},
      filename: "reporte_#{id}.txt",
      content_type: "text/plain"
    )
  end

  def delete(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)
    {:ok, _execution} = Executions.delete_execution(execution)

    conn
    |> put_flash(:info, "Execution deleted successfully.")
    |> redirect(to: ~p"/executions")
  end
end
