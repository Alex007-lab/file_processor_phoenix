defmodule FileProcessorWeb.ExecutionHTML do
  use FileProcessorWeb, :html

  embed_templates "execution_html/*"

  @doc """
  Parsea el resultado de la ejecución para mostrar en formato HTML
  """
  def parse_execution_files(execution) do
    # Benchmark no tiene secciones por archivo — mostrar el reporte completo como un único item
    if execution.mode == "benchmark" do
      [%{
        name:         "Benchmark completo",
        extension:    "",
        details:      execution.result,
        metrics:      %{},
        has_error:    false,
        status_class: "badge-success",
        status_text:  "Éxito"
      }]
    else
      parse_regular_files(execution)
    end
  end

  defp parse_regular_files(execution) do
    files = String.split(execution.files, ", ")

    Enum.map(files, fn file ->
      extension = Path.extname(file)

      # Extraer la sección del archivo usando el formato [archivo] - TIPO
      file_result = extract_file_section(execution.result, file)

      # Extraer métricas básicas
      metrics = extract_metrics(file_result, extension)

      # Determinar si el archivo tuvo éxito leyendo el campo Estado del reporte
      has_error = file_result == "No se encontraron resultados para este archivo" ||
                  String.contains?(file_result, "• Estado: error") ||
                  String.contains?(file_result, "• Estado: parcial")

      is_partial = String.contains?(file_result, "• Estado: parcial")
      status_class = cond do
        not has_error                -> "badge-success"
        is_partial                   -> "badge-warning"
        true                         -> "badge-error"
      end
      status_text = cond do
        not has_error -> "Éxito"
        is_partial    -> "Parcial"
        true          -> "Error"
      end

      %{
        name: file,
        extension: extension,
        details: file_result,
        metrics: metrics,
        has_error: has_error,
        status_class: status_class,
        status_text: status_text
      }
    end)
  end

  @doc """
  Extrae la sección de un archivo específico usando el formato [archivo] - TIPO
  """
  def extract_file_section(report, file) do
    pattern = ~r/\[#{Regex.escape(file)}\].*?(?=\n\[|\Z)/s

    case Regex.run(pattern, report) do
      [match] -> String.trim(match)
      nil -> "No se encontraron resultados para este archivo"
    end
  end

  @doc """
  Extrae métricas básicas del resultado del archivo
  """
  def extract_metrics(file_result, extension) do
    base_metrics = %{
      total_lines: extract_value(file_result, ~r/Total líneas: (\d+)/) ||
                   extract_value(file_result, ~r/Líneas totales: (\d+)/) ||
                   extract_value(file_result, ~r/líneas: (\d+)/) || "",
      debug: extract_value(file_result, ~r/DEBUG:?\s*(\d+)/) || "",
      info: extract_value(file_result, ~r/INFO:?\s*(\d+)/) || "",
      warn: extract_value(file_result, ~r/WARN:?\s*(\d+)/) || "",
      error: extract_value(file_result, ~r/ERROR:?\s*(\d+)/) || "",
      fatal: extract_value(file_result, ~r/FATAL:?\s*(\d+)/) || "",
      total_users: extract_value(file_result, ~r/Total usuarios: (\d+)/) || "",
      active_users: extract_value(file_result, ~r/Usuarios activos: (\d+)/) || "",
      total_sessions: extract_value(file_result, ~r/Total sesiones: (\d+)/) || "",
      valid_records: extract_value(file_result, ~r/Registros válidos: (\d+)/) ||
                     extract_value(file_result, ~r/líneas válidas: (\d+)/) || "",
      total_sales: extract_value(file_result, ~r/Ventas totales: \$([\d\.]+)/) || "",
      unique_products: extract_value(file_result, ~r/Productos únicos: (\d+)/) || ""
    }

    # Filtrar solo las métricas relevantes para este tipo de archivo
    case extension do
      ".log" ->
        Map.take(base_metrics, [:total_lines, :debug, :info, :warn, :error, :fatal])
      ".json" ->
        Map.take(base_metrics, [:total_users, :active_users, :total_sessions])
      ".csv" ->
        Map.take(base_metrics, [:valid_records, :total_sales, :unique_products])
      _ ->
        %{}
    end
  end

  defp extract_value(text, regex) do
    case Regex.run(regex, text) do
      [_, value] -> value
      nil -> nil
    end
  end

  @doc """
  Retorna el ícono según la extensión
  """
  def file_icon(extension) do
    case extension do
      ".csv" -> "📊"
      ".json" -> "📋"
      ".log" -> "📝"
      _ -> "📄"
    end
  end

  @doc """
  Obtiene el resumen general de la ejecución
  """
  def get_execution_summary(execution) do
    total_time = execution.total_time

    {successes, errors} =
      if execution.mode == "benchmark" do
        files_count = execution.files |> String.split(", ") |> length()
        {files_count, 0}
      else
        successes = length(Regex.scan(~r/• Estado: éxito/, execution.result))
        errors    = length(Regex.scan(~r/• Estado: error/, execution.result)) +
                    length(Regex.scan(~r/• Estado: parcial/, execution.result))
        # fallback: si el reporte no tiene ese formato intentar con ✅/❌
        if successes + errors == 0 do
          case Regex.run(~r/✅ Exitosos: (\d+).*❌ Errores:\s+(\d+)/s, execution.result) do
            [_, s, e] -> {String.to_integer(s), String.to_integer(e)}
            nil       -> {0, 0}
          end
        else
          {successes, errors}
        end
      end

    %{
      total_time: total_time,
      successes: successes,
      errors: errors,
      total_files: successes + errors
    }
  end

  # ---------------------------------------------------------------------------
  # Helpers de presentación (disponibles para templates)
  # ---------------------------------------------------------------------------

  def format_datetime(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  def format_date(datetime),     do: Calendar.strftime(datetime, "%d/%m/%Y")
  def format_time(datetime),     do: Calendar.strftime(datetime, "%H:%M")

  def mode_badge_color(mode) do
    case mode do
      "sequential" -> "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"
      "parallel"   -> "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
      "benchmark"  -> "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400"
      _            -> "bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
    end
  end

  def mode_display_name(mode) do
    case mode do
      "sequential" -> "📋 Secuencial"
      "parallel"   -> "⚡ Paralelo"
      "benchmark"  -> "📊 Benchmark"
      _            -> mode
    end
  end

  def extract_benchmark_data(report) when is_binary(report) do
    sequential =
      extract_value(report, ~r/Sequential Mode:\s*(\d+)/i) ||
      extract_value(report, ~r/Secuencial:\s*(\d+)/i) ||
      extract_value(report, ~r/📈\s*Secuencial:\s*(\d+)/)

    parallel =
      extract_value(report, ~r/Parallel Mode:\s*(\d+)/i) ||
      extract_value(report, ~r/Paralelo:\s*(\d+)/i) ||
      extract_value(report, ~r/⚡\s*Paralelo:\s*(\d+)/)

    seq = if is_binary(sequential), do: String.to_integer(sequential), else: nil
    par = if is_binary(parallel), do: String.to_integer(parallel), else: nil

    case {seq, par} do
      {seq, par} when is_integer(seq) and is_integer(par) ->
        time_saved  = seq - par
        percent     = if seq > 0, do: (seq - par) / seq * 100, else: 0.0
        improvement = if par > 0, do: seq / par, else: 0.0

        %{
          sequential_ms:  seq,
          parallel_ms:    par,
          improvement:    Float.round(improvement, 2),
          time_saved:     abs(time_saved),
          percent_faster: Float.round(abs(percent), 1),
          faster_mode:
            cond do
              time_saved > 0 -> "⚡ Paralelo más rápido"
              time_saved < 0 -> "📋 Secuencial más rápido"
              true           -> "⚖️ Igual rendimiento"
            end
        }

      _ -> nil
    end
  end

  def extract_benchmark_data(_), do: nil
end
