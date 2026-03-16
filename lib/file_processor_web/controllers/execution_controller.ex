defmodule FileProcessorWeb.ExecutionController do
  use FileProcessorWeb, :controller

  alias FileProcessor.Executions

  def download(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)

    send_download(conn, {:binary, execution.result},
      filename: "execution_#{execution.id}.txt",
      content_type: "text/plain"
    )
  end

  def delete(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)
    {:ok, _execution} = Executions.delete_execution(execution)

    conn
    |> put_flash(:info, "Ejecución eliminada exitosamente")
    |> redirect(to: ~p"/executions")
  end

  def delete_all(conn, _params) do
    Executions.delete_all_executions()

    conn
    |> put_flash(:info, "Todo el historial ha sido eliminado")
    |> redirect(to: ~p"/executions")
  end
end
