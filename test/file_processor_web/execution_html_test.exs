defmodule FileProcessorWeb.ExecutionHTMLTest do
  use ExUnit.Case, async: true

  alias FileProcessorWeb.ExecutionHTML

  # ---------------------------------------------------------------------------
  # file_icon/1
  # ---------------------------------------------------------------------------

  describe "file_icon/1" do
    test "CSV devuelve 📊" do
      assert ExecutionHTML.file_icon(".csv") == "📊"
    end

    test "JSON devuelve 📋" do
      assert ExecutionHTML.file_icon(".json") == "📋"
    end

    test "LOG devuelve 📝" do
      assert ExecutionHTML.file_icon(".log") == "📝"
    end

    test "extensión desconocida devuelve 📄" do
      assert ExecutionHTML.file_icon(".txt") == "📄"
      assert ExecutionHTML.file_icon("")     == "📄"
    end
  end

  # ---------------------------------------------------------------------------
  # format_datetime/1
  # ---------------------------------------------------------------------------

  describe "format_datetime/1" do
    test "formatea fecha y hora correctamente" do
      dt = ~U[2026-03-10 17:34:00Z]
      assert ExecutionHTML.format_datetime(dt) == "10/03/2026 17:34"
    end
  end

  describe "format_date/1" do
    test "formatea solo la fecha" do
      dt = ~U[2026-03-10 17:34:00Z]
      assert ExecutionHTML.format_date(dt) == "10/03/2026"
    end
  end

  describe "format_time/1" do
    test "formatea solo la hora" do
      dt = ~U[2026-03-10 17:34:00Z]
      assert ExecutionHTML.format_time(dt) == "17:34"
    end
  end

  # ---------------------------------------------------------------------------
  # extract_metrics/2
  # ---------------------------------------------------------------------------

  describe "extract_metrics/2" do
    test "extrae métricas CSV correctamente" do
      report = """
      [ventas.csv] - CSV
      ═══════════════════════════════
      • Estado: éxito
      • Registros válidos: 10
      • Productos únicos: 5
      • Ventas totales: $999.99
      """

      metrics = ExecutionHTML.extract_metrics(report, ".csv")
      assert metrics.valid_records   == "10"
      assert metrics.unique_products == "5"
      assert metrics.total_sales     == "999.99"
    end

    test "extrae métricas JSON correctamente" do
      report = """
      [usuarios.json] - JSON
      ═══════════════════════════════
      • Estado: éxito
      • Total usuarios: 20
      • Usuarios activos: 15
      • Total sesiones: 30
      """

      metrics = ExecutionHTML.extract_metrics(report, ".json")
      assert metrics.total_users    == "20"
      assert metrics.active_users   == "15"
      assert metrics.total_sessions == "30"
    end

    test "extrae métricas LOG correctamente" do
      report = """
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

      metrics = ExecutionHTML.extract_metrics(report, ".log")
      assert metrics.total_lines == "72"
      assert metrics.debug       == "6"
      assert metrics.info        == "49"
      assert metrics.warn        == "7"
      assert metrics.error       == "9"
      assert metrics.fatal       == "1"
    end

    test "solo devuelve métricas del tipo correspondiente" do
      report = "• Total usuarios: 5\n• Registros válidos: 10"

      csv_metrics  = ExecutionHTML.extract_metrics(report, ".csv")
      json_metrics = ExecutionHTML.extract_metrics(report, ".json")

      refute Map.has_key?(csv_metrics, :total_users)
      refute Map.has_key?(json_metrics, :valid_records)
    end
  end

  # ---------------------------------------------------------------------------
  # parse_execution_files/1
  # ---------------------------------------------------------------------------

  describe "parse_execution_files/1" do
    test "modo benchmark devuelve un único item con el reporte completo" do
      execution = %{
        mode:   "benchmark",
        files:  "ventas.csv",
        result: "📈 Secuencial: 100 ms\n⚡ Paralelo: 60 ms"
      }

      files = ExecutionHTML.parse_execution_files(execution)
      assert length(files) == 1
      assert hd(files).name      == "Benchmark completo"
      assert hd(files).has_error == false
    end

    test "modo sequential parsea archivos individuales" do
      execution = %{
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
      }

      files = ExecutionHTML.parse_execution_files(execution)
      assert length(files) == 1
      file = hd(files)
      assert file.name       == "ventas.csv"
      assert file.has_error  == false
      assert file.status_text == "Éxito"
    end

    test "detecta estado parcial correctamente" do
      execution = %{
        mode:   "sequential",
        files:  "corrupto.csv",
        result: """
        [corrupto.csv] - CSV
        ═══════════════════════════════
        • Estado: parcial
        • Registros válidos: 3
        """
      }

      files = ExecutionHTML.parse_execution_files(execution)
      file  = hd(files)
      assert file.has_error   == true
      assert file.status_text == "Parcial"
    end

    test "detecta estado error correctamente" do
      execution = %{
        mode:   "sequential",
        files:  "roto.csv",
        result: """
        [roto.csv] - ERROR
        ═══════════════════════════════
        • Estado: error
        • Razón: archivo inválido
        """
      }

      files = ExecutionHTML.parse_execution_files(execution)
      file  = hd(files)
      assert file.has_error   == true
      assert file.status_text == "Error"
    end
  end

  # ---------------------------------------------------------------------------
  # extract_benchmark_data/1
  # ---------------------------------------------------------------------------

  describe "extract_benchmark_data/1" do
    test "extrae tiempos con formato emoji" do
      report = "📈 Secuencial: 200 ms\n⚡ Paralelo:    80 ms"
      data   = ExecutionHTML.extract_benchmark_data(report)

      assert data.sequential_ms == 200
      assert data.parallel_ms   == 80
    end

    test "extrae tiempos con formato texto plano" do
      report = "Secuencial: 150 ms\nParalelo: 90 ms"
      data   = ExecutionHTML.extract_benchmark_data(report)

      assert data.sequential_ms == 150
      assert data.parallel_ms   == 90
    end

    test "devuelve nil si no encuentra datos" do
      assert ExecutionHTML.extract_benchmark_data("sin datos") == nil
      assert ExecutionHTML.extract_benchmark_data(nil)         == nil
    end
  end
end
