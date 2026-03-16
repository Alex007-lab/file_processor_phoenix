defmodule FileProcessor.ReportBuilderTest do
  use ExUnit.Case, async: true

  alias FileProcessor.ReportBuilder

  # ---------------------------------------------------------------------------
  # build_sequential/2
  # ---------------------------------------------------------------------------

  describe "build_sequential/2" do
    test "incluye el modo en el reporte" do
      result = ReportBuilder.build_sequential([], 100)
      assert result =~ "SECUENCIAL"
    end

    test "incluye el tiempo total" do
      result = ReportBuilder.build_sequential([], 250)
      assert result =~ "250 ms"
    end

    test "cuenta correctamente exitosos y errores" do
      results = [
        %{type: :csv, status: :success, file_name: "a.csv",
          valid_records: 5, unique_products: 3, total_sales: 100.0},
        %{type: :csv, status: :error, file_name: "b.csv", error: "formato inválido"}
      ]

      report = ReportBuilder.build_sequential(results, 100)
      assert report =~ "Exitosos: 1"
      assert report =~ "Errores:   1"
    end

    test "cuenta parciales como no-exitosos" do
      results = [
        %{type: :csv, status: :partial, file_name: "a.csv",
          valid_records: 2, unique_products: 1, total_sales: 50.0}
      ]

      report = ReportBuilder.build_sequential(results, 100)
      assert report =~ "Exitosos: 0"
      assert report =~ "Errores:   1"
    end

    test "formatea resultado CSV correctamente" do
      results = [
        %{type: :csv, status: :success, file_name: "ventas.csv",
          valid_records: 10, unique_products: 5, total_sales: 999.99}
      ]

      report = ReportBuilder.build_sequential(results, 100)
      assert report =~ "[ventas.csv]"
      assert report =~ "Registros válidos: 10"
      assert report =~ "Productos únicos: 5"
      assert report =~ "$999.99"
      assert report =~ "Estado: éxito"
    end

    test "formatea resultado JSON correctamente" do
      results = [
        %{type: :json, status: :success, file_name: "usuarios.json",
          total_users: 20, active_users: 15, total_sessions: 30}
      ]

      report = ReportBuilder.build_sequential(results, 100)
      assert report =~ "[usuarios.json]"
      assert report =~ "Total usuarios: 20"
      assert report =~ "Usuarios activos: 15"
      assert report =~ "Total sesiones: 30"
    end

    test "formatea resultado LOG correctamente" do
      results = [
        %{type: :log, status: :success, file_name: "sistema.log",
          total_lines: 72, debug: 6, info: 49, warn: 7, error: 9, fatal: 1}
      ]

      report = ReportBuilder.build_sequential(results, 100)
      assert report =~ "[sistema.log]"
      assert report =~ "Total líneas: 72"
      assert report =~ "DEBUG: 6"
      assert report =~ "INFO:  49"
      assert report =~ "WARN:  7"
      assert report =~ "ERROR: 9"
      assert report =~ "FATAL: 1"
    end

    test "formatea estado parcial correctamente" do
      results = [
        %{type: :csv, status: :partial, file_name: "corrupto.csv",
          valid_records: 3, unique_products: 2, total_sales: 50.0}
      ]

      report = ReportBuilder.build_sequential(results, 100)
      assert report =~ "Estado: parcial"
    end
  end

  # ---------------------------------------------------------------------------
  # build_parallel/2
  # ---------------------------------------------------------------------------

  describe "build_parallel/2" do
    test "incluye el modo en el reporte" do
      result = ReportBuilder.build_parallel(%{results: [], successes: 0, errors: 0}, 100)
      assert result =~ "PARALELO"
    end

    test "muestra conteo de exitosos y errores" do
      results = [
        %{type: :csv, status: :success, file_name: "a.csv",
          valid_records: 1, unique_products: 1, total_sales: 10.0}
      ]

      report = ReportBuilder.build_parallel(%{results: results, successes: 1, errors: 0}, 50)
      assert report =~ "Exitosos: 1"
      assert report =~ "Errores:   0"
    end
  end

  # ---------------------------------------------------------------------------
  # build_benchmark/2
  # ---------------------------------------------------------------------------

  describe "build_benchmark/2" do
    @benchmark_data %{
      sequential_ms: 200,
      parallel_ms:   80,
      improvement:   2.5,
      percent_faster: 60.0,
      full_report:   "Reporte completo del benchmark"
    }

    test "incluye tiempos secuencial y paralelo" do
      report = ReportBuilder.build_benchmark(@benchmark_data, 300)
      assert report =~ "200 ms"
      assert report =~ "80 ms"
    end

    test "indica que paralelo es más rápido" do
      report = ReportBuilder.build_benchmark(@benchmark_data, 300)
      assert report =~ "Paralelo es más rápido"
    end

    test "indica que secuencial es más rápido cuando corresponde" do
      data = %{@benchmark_data | sequential_ms: 80, parallel_ms: 200}
      report = ReportBuilder.build_benchmark(data, 300)
      assert report =~ "Secuencial es más rápido"
    end

    test "incluye el reporte completo del core" do
      report = ReportBuilder.build_benchmark(@benchmark_data, 300)
      assert report =~ "Reporte completo del benchmark"
    end

    test "incluye el tiempo total" do
      report = ReportBuilder.build_benchmark(@benchmark_data, 350)
      assert report =~ "350 ms"
    end
  end
end
