defmodule FileProcessorWeb.ExecutionControllerTest do
  use FileProcessorWeb.ConnCase

  import FileProcessor.ExecutionsFixtures

  # ---------------------------------------------------------------------------
  # download
  # ---------------------------------------------------------------------------

  describe "download" do
    test "descarga el reporte como archivo .txt", %{conn: conn} do
      execution = execution_fixture(%{result: "Reporte de prueba"})

      conn = get(conn, ~p"/executions/#{execution.id}/download")

      assert response(conn, 200) =~ "Reporte de prueba"
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/plain"
      assert get_resp_header(conn, "content-disposition") |> hd() =~
               "execution_#{execution.id}.txt"
    end

    test "devuelve 404 si la ejecución no existe", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/executions/0/download")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # delete
  # ---------------------------------------------------------------------------

  describe "delete" do
    test "elimina la ejecución y redirige al historial", %{conn: conn} do
      execution = execution_fixture()

      conn = delete(conn, ~p"/executions/#{execution.id}")

      assert redirected_to(conn) == ~p"/executions"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "eliminada"

      assert_raise Ecto.NoResultsError, fn ->
        FileProcessor.Executions.get_execution!(execution.id)
      end
    end

    test "devuelve 404 si la ejecución no existe", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, ~p"/executions/0")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # delete_all
  # ---------------------------------------------------------------------------

  describe "delete_all" do
    test "elimina todas las ejecuciones y redirige", %{conn: conn} do
      execution_fixture()
      execution_fixture()

      conn = delete(conn, ~p"/executions/delete_all")

      assert redirected_to(conn) == ~p"/executions"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "historial"
      assert FileProcessor.Executions.list_executions() == []
    end

    test "funciona aunque no haya ejecuciones", %{conn: conn} do
      conn = delete(conn, ~p"/executions/delete_all")
      assert redirected_to(conn) == ~p"/executions"
    end
  end
end
