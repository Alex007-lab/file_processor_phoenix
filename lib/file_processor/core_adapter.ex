defmodule ProcesadorArchivos.CoreAdapter do
  @moduledoc """
  Adaptador entre Phoenix y el core ProcesadorArchivos.
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

  # Versión mejorada para benchmark
  def run_benchmark(file_paths) when is_list(file_paths) do
    case file_paths do
      # Si es un solo elemento y es directorio
      [dir] ->
        if File.dir?(dir) do
          run_benchmark_dir(dir)
        else
          run_benchmark_files(file_paths)
        end

      # Si son múltiples archivos
      files when is_list(files) ->
        run_benchmark_files(files)

      _ ->
        {:error, "Benchmark requiere un directorio o lista de archivos válida"}
    end
  end

  # Benchmark con directorio (usa el core original)
  defp run_benchmark_dir(dir) do
    result = ProcesadorArchivos.benchmark(dir, %{})

    cond do
      # Caso éxito - resultado es mapa con las claves esperadas
      is_map(result) and Map.has_key?(result, :sequential_ms) ->
        seq = Map.get(result, :sequential_ms, 0)
        par = Map.get(result, :parallel_ms, 0)
        count = Map.get(result, :files_count, 0)

        # Calcular mejora correctamente
        improvement = if par > 0, do: seq / par, else: 1.0

        # Porcentaje de mejora
        percent = if seq > 0, do: (seq - par) / seq * 100, else: 0.0

        # Tiempo ahorrado
        time_saved = seq - par

        # Formatear para mostrar
        percent_faster = Float.round(percent, 1)
        improvement_rounded = Float.round(improvement, 2)

        {:ok, %{
          type: "benchmark",
          sequential_ms: seq,
          parallel_ms: par,
          improvement: improvement_rounded,
          files_count: count,
          percent_faster: percent_faster,
          time_saved: time_saved,
          details: result
        }}

      # Caso error - verificar si es un mapa con :error o una tupla
      is_map(result) and Map.has_key?(result, :error) ->
        error_msg = Map.get(result, :error, "Error desconocido")
        {:error, "Error en benchmark: #{error_msg}"}

      # Caso tupla de error
      match?({:error, _}, result) ->
        {:error, "Error en benchmark: #{inspect(result)}"}

      # Otros casos
      true ->
        {:ok, %{type: "benchmark", result: inspect(result)}}
    end
  end

  # Benchmark con lista de archivos (crea directorio temporal)
  defp run_benchmark_files(files) do
    # Verificar que hay archivos
    if length(files) == 0 do
      {:error, "No hay archivos para benchmark"}
    else
      # Crear directorio temporal único
      timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(":", "-")
      temp_dir = Path.join(System.tmp_dir!(), "benchmark_#{timestamp}")
      File.mkdir_p!(temp_dir)

      try do
        # Copiar archivos al directorio temporal
        Enum.each(files, fn file_path ->
          dest = Path.join(temp_dir, Path.basename(file_path))
          File.cp!(file_path, dest)
        end)

        # Ejecutar benchmark en el directorio temporal
        run_benchmark_dir(temp_dir)
      after
        # Limpiar archivos temporales
        File.rm_rf(temp_dir)
      end
    end
  end

  # Helper para extraer resultados del benchmark
  def extract_benchmark_summary(result) do
    case result do
      {:ok, data} when is_map(data) ->
        seq = Map.get(data, :sequential_ms, 0)
        par = Map.get(data, :parallel_ms, 0)
        imp = Map.get(data, :improvement, 0)
        time_saved = Map.get(data, :time_saved, 0)
        percent = Map.get(data, :percent_faster, 0)

        # Determinar qué modo es más rápido
        faster = cond do
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
