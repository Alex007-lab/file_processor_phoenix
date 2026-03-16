defmodule FileProcessorWeb.ExecutionShowLiveTest do
  use FileProcessorWeb.ConnCase

  import Phoenix.LiveViewTest
  import FileProcessor.ExecutionsFixtures

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  describe "mount" do
    test "renderiza el reporte de una ejecución sequential", %{conn: conn} do
      execution = execution_fixture(%{
        mode:   "sequential",
        files:  "ventas.csv",
        result: """
        [ventas.csv] - CSV
        ═══════════════════════════════
        • Estado: éxito
        • Registros válidos: 10
        • Productos únicos: 5
        • Ventas totales: $500.00
        """
      })

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "Reporte de Ejecución"
      assert html =~ "ventas.csv"
      assert html =~ "Secuencial"
    end

    test "muestra las tarjetas de resumen", %{conn: conn} do
      execution = execution_fixture()

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "Modo"
      assert html =~ "Archivos"
      assert html =~ "Tiempo total"
      assert html =~ "Resultado"
    end

    test "muestra métricas CSV al expandir", %{conn: conn} do
      execution = execution_fixture(%{
        mode:   "sequential",
        files:  "ventas.csv",
        result: """
        [ventas.csv] - CSV
        ═══════════════════════════════
        • Estado: éxito
        • Registros válidos: 8
        • Productos únicos: 4
        • Ventas totales: $750.00
        """
      })

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "Registros válidos"
      assert html =~ "Productos únicos"
      assert html =~ "Ventas totales"
    end

    test "muestra métricas LOG al expandir", %{conn: conn} do
      execution = execution_fixture(%{
        mode:   "sequential",
        files:  "sistema.log",
        result: """
        [sistema.log] - LOG
        ═══════════════════════════════
        • Estado: éxito
        • Total líneas: 72
        • Distribución:
            DEBUG: 6
            INFO:  49
            WARN:  7
            ERROR: 9
            FATAL: 1
        """
      })

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "DEBUG"
      assert html =~ "INFO"
      assert html =~ "WARN"
      assert html =~ "ERROR"
      assert html =~ "FATAL"
    end

    test "muestra sección benchmark cuando el modo es benchmark", %{conn: conn} do
      execution = execution_fixture_benchmark()

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "Benchmark: Secuencial vs Paralelo"
      assert html =~ "benchmarkChart"
    end

    test "no muestra sección benchmark en modo sequential", %{conn: conn} do
      execution = execution_fixture()

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      refute html =~ "Benchmark: Secuencial vs Paralelo"
    end

    test "muestra badge Parcial cuando hay errores", %{conn: conn} do
      execution = execution_fixture_partial(%{
        files:  "corrupto.csv",
        result: """
        [corrupto.csv] - CSV
        ═══════════════════════════════
        • Estado: parcial
        • Registros válidos: 3
        """
      })

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "Parcial"
    end

    test "muestra Completado exitosamente cuando no hay errores", %{conn: conn} do
      execution = execution_fixture(%{
        files:  "ventas.csv",
        result: """
        [ventas.csv] - CSV
        ═══════════════════════════════
        • Estado: éxito
        • Registros válidos: 10
        • Productos únicos: 5
        • Ventas totales: $500.00
        """
      })

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "Completado exitosamente"
    end

    test "lanza 404 si la ejecución no existe", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/executions/0")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Navegación
  # ---------------------------------------------------------------------------

  describe "navegación" do
    test "botón volver al historial navega a /executions", %{conn: conn} do
      execution = execution_fixture()

      {:ok, view, _html} = live(conn, ~p"/executions/#{execution.id}")

      assert view |> element("a", "Volver al historial") |> render() =~ "/executions"
    end

    test "botón descargar TXT apunta a la ruta de descarga", %{conn: conn} do
      execution = execution_fixture()

      {:ok, _view, html} = live(conn, ~p"/executions/#{execution.id}")

      assert html =~ "/executions/#{execution.id}/download"
    end
  end
end
