defmodule FileProcessorWeb.ExecutionLiveTest do
  use FileProcessorWeb.ConnCase

  import Phoenix.LiveViewTest
  import FileProcessor.ExecutionsFixtures

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  describe "mount" do
    test "renderiza el historial correctamente", %{conn: conn} do
      execution_fixture(%{mode: "sequential"})

      {:ok, _view, html} = live(conn, ~p"/executions")

      assert html =~ "Historial de Ejecuciones"
      assert html =~ "ventas.csv"
    end

    test "muestra las estadísticas en el dashboard", %{conn: conn} do
      execution_fixture(%{mode: "sequential"})
      execution_fixture_parallel()

      {:ok, _view, html} = live(conn, ~p"/executions")

      assert html =~ "Secuencial"
      assert html =~ "Paralelo"
    end

    test "muestra estado vacío cuando no hay ejecuciones", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/executions")
      assert html =~ "0"
    end
  end

  # ---------------------------------------------------------------------------
  # Filtros
  # ---------------------------------------------------------------------------

  describe "filtros" do
    test "filtra por modo sequential", %{conn: conn} do
      execution_fixture(%{mode: "sequential", files: "ventas.csv"})
      execution_fixture_parallel()

      {:ok, view, _html} = live(conn, ~p"/executions")
      html = view |> element("button", "Secuencial") |> render_click()

      assert html =~ "ventas.csv"
      refute html =~ "usuarios.json"
    end

    test "filtra por modo parallel", %{conn: conn} do
      execution_fixture(%{mode: "sequential", files: "ventas.csv"})
      execution_fixture_parallel()

      {:ok, view, _html} = live(conn, ~p"/executions")
      html = view |> element("button", "Paralelo") |> render_click()

      assert html =~ "usuarios.json"
      refute html =~ "ventas.csv"
    end

    test "filtra por modo benchmark", %{conn: conn} do
      execution_fixture(%{mode: "sequential"})
      execution_fixture_benchmark()

      {:ok, view, _html} = live(conn, ~p"/executions")
      html = view |> element("button", "Benchmark") |> render_click()

      assert html =~ "BENCHMARK"
    end

    test "Todos muestra todas las ejecuciones", %{conn: conn} do
      execution_fixture(%{mode: "sequential", files: "ventas.csv"})
      execution_fixture_parallel()

      {:ok, view, _html} = live(conn, ~p"/executions")

      view |> element("button", "Secuencial") |> render_click()
      html = view |> element("button", "Todos") |> render_click()

      assert html =~ "ventas.csv"
      assert html =~ "usuarios.json"
    end
  end

  # ---------------------------------------------------------------------------
  # Paginación
  # ---------------------------------------------------------------------------

  describe "paginación" do
    test "no muestra controles si hay 10 o menos ejecuciones", %{conn: conn} do
      for _ <- 1..5, do: execution_fixture()

      {:ok, _view, html} = live(conn, ~p"/executions")
      refute html =~ "Siguiente"
      refute html =~ "Anterior"
    end

    test "muestra controles si hay más de 10 ejecuciones", %{conn: conn} do
      for _ <- 1..11, do: execution_fixture()

      {:ok, _view, html} = live(conn, ~p"/executions")
      assert html =~ "Siguiente"
      assert html =~ "Página 1 de 2"
    end

    test "navega a la página siguiente", %{conn: conn} do
      for _ <- 1..11, do: execution_fixture()

      {:ok, view, _html} = live(conn, ~p"/executions")
      html = view |> element("button", "Siguiente") |> render_click()

      assert html =~ "Página 2 de 2"
    end

    test "navega a la página anterior", %{conn: conn} do
      for _ <- 1..11, do: execution_fixture()

      {:ok, view, _html} = live(conn, ~p"/executions")
      view |> element("button", "Siguiente") |> render_click()
      html = view |> element("button", "Anterior") |> render_click()

      assert html =~ "Página 1 de 2"
    end

    test "al filtrar resetea a página 1", %{conn: conn} do
      for _ <- 1..11, do: execution_fixture(%{mode: "sequential"})

      {:ok, view, _html} = live(conn, ~p"/executions")
      view |> element("button", "Siguiente") |> render_click()
      html = view |> element("button", "Secuencial") |> render_click()

      assert html =~ "Página 1 de"
    end
  end

  # ---------------------------------------------------------------------------
  # Modal de eliminación
  # ---------------------------------------------------------------------------

  describe "modal de eliminación" do
    test "abre modal al hacer click en eliminar fila", %{conn: conn} do
      execution = execution_fixture()

      {:ok, view, _html} = live(conn, ~p"/executions")
      html = view |> element("[phx-click='confirm_delete'][phx-value-id='#{execution.id}']") |> render_click()

      assert html =~ "Eliminar ejecución"
      assert html =~ "Esta acción no se puede deshacer"
    end

    test "abre modal al hacer click en limpiar historial", %{conn: conn} do
      execution_fixture()

      {:ok, view, _html} = live(conn, ~p"/executions")
      html = view |> element("[phx-click='confirm_delete_all']") |> render_click()

      assert html =~ "Limpiar historial completo"
    end

    test "cancela el modal con el botón Cancelar", %{conn: conn} do
      execution = execution_fixture()

      {:ok, view, _html} = live(conn, ~p"/executions")
      view |> element("[phx-click='confirm_delete'][phx-value-id='#{execution.id}']") |> render_click()
      html = view |> element("button[phx-click='cancel_modal']") |> render_click()

      refute html =~ "Eliminar ejecución"
    end

    test "elimina la ejecución al confirmar", %{conn: conn} do
      execution = execution_fixture(%{files: "borrar.csv"})

      {:ok, view, _html} = live(conn, ~p"/executions")
      view |> element("[phx-click='confirm_delete'][phx-value-id='#{execution.id}']") |> render_click()
      html = view |> element("[phx-click='delete'][phx-value-id='#{execution.id}']") |> render_click()

      refute html =~ "borrar.csv"
      assert FileProcessor.Executions.list_executions() == []
    end

    test "elimina todas las ejecuciones al confirmar delete_all", %{conn: conn} do
      execution_fixture()
      execution_fixture()

      {:ok, view, _html} = live(conn, ~p"/executions")
      view |> element("[phx-click='confirm_delete_all']") |> render_click()
      view |> element("[phx-click='delete_all']") |> render_click()

      assert FileProcessor.Executions.list_executions() == []
    end
  end
end
