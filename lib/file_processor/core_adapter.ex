defmodule ProcesadorArchivos.CoreAdapter do
  @moduledoc """
  Adaptador entre Phoenix y el core ProcesadorArchivos.
  Versión que NO modifica el core pero captura los reportes.
  """

  def process_sequential(file_paths) do
    Enum.map(file_paths, fn file ->
      ProcesadorArchivos.procesar_con_manejo_errores(file, %{
        timeout: 5000
      })
    end)
  end

  def process_parallel(file_paths) do
    ProcesadorArchivos.process_parallel(file_paths)
  end

  def run_benchmark(file_paths) when is_list(file_paths) do
    if file_paths == [] do
      {:error, "No hay archivos para benchmark"}
    else
      temp_root =
        Path.join(:code.priv_dir(:file_processor), "benchmark_temp")

      File.mkdir_p!(temp_root)

      timestamp =
        DateTime.utc_now()
        |> DateTime.to_unix()

      temp_dir =
        Path.join(temp_root, "run_#{timestamp}")

      File.mkdir_p!(temp_dir)

      try do
        Enum.each(file_paths, fn file ->
          dest = Path.join(temp_dir, Path.basename(file))
          File.cp!(file, dest)
        end)

        # Capturar la salida del benchmark
        result = ProcesadorArchivos.benchmark(temp_dir, %{})

        if is_map(result) do
          # Intentar obtener el contenido del reporte de varias formas
          content =
            cond do
              # Si el resultado ya trae el contenido
              Map.has_key?(result, :benchmark_content) ->
                result.benchmark_content

              # Si tiene la ruta del reporte, intentamos leerlo
              Map.has_key?(result, :benchmark_report) ->
                report_path = result.benchmark_report
                case File.read(report_path) do
                  {:ok, c} ->
                    # Leer y luego eliminar el archivo temporal
                    File.rm(report_path)
                    c
                  _ ->
                    "Benchmark completado pero no se pudo leer el reporte"
                end

              # Si no hay reporte, generamos uno basado en los datos
              true ->
                """
                BENCHMARK RESULTS
                ━━━━━━━━━━━━━━━━━━━━━━━━━
                Secuencial: #{Map.get(result, :sequential_ms, 0)} ms
                Paralelo:   #{Map.get(result, :parallel_ms, 0)} ms
                Mejora:      #{Map.get(result, :improvement, 0)}x
                """
            end

          {:ok,
           %{
             full_report: content,
             sequential_ms: Map.get(result, :sequential_ms, 0),
             parallel_ms: Map.get(result, :parallel_ms, 0),
             improvement: Map.get(result, :improvement, 0),
             percent_faster: Map.get(result, :percent_faster, 0)
           }}
        else
          {:error, "Resultado inesperado del benchmark"}
        end
      after
        # Limpiar archivos temporales
        File.rm_rf(temp_dir)
      end
    end
  end

  def extract_benchmark_summary(result) do
    case result do
      {:ok, data} when is_map(data) ->
        seq = Map.get(data, :sequential_ms, 0)
        par = Map.get(data, :parallel_ms, 0)
        imp = Map.get(data, :improvement, 0)
        time_saved = seq - par
        percent = Map.get(data, :percent_faster, 0)

        faster =
          cond do
            time_saved > 0 -> "⚡ Paralelo es más rápido"
            time_saved < 0 -> "📋 Secuencial es más rápido"
            true -> "⚖️ Mismo rendimiento"
          end

        """
        📊 BENCHMARK RESULTS
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        📈 Secuencial: #{seq} ms
        ⚡ Paralelo:    #{par} ms
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #{faster}
        🚀 Factor de mejora: #{imp}x
        ⏱️  Diferencia: #{abs(time_saved)} ms
        📊 Eficiencia: #{abs(percent)}% #{if percent > 0, do: "más rápido", else: "más lento"}
        """

      {:error, reason} when is_binary(reason) ->
        "❌ Error en benchmark: #{reason}"

      {:error, reason} ->
        "❌ Error en benchmark: #{inspect(reason)}"

      _ ->
        "❌ Resultado inesperado: #{inspect(result)}"
    end
  end
end
