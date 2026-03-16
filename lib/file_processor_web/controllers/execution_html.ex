defmodule FileProcessorWeb.ExecutionHTML do
  use FileProcessorWeb, :html

  embed_templates "execution_html/*"

  # ---------------------------------------------------------------------------
  # Parseo de archivos — usado por ExecutionShowLive
  # ---------------------------------------------------------------------------

  def parse_execution_files(execution) do
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
      extension  = Path.extname(file)
      file_result = extract_file_section(execution.result, file)
      metrics    = extract_metrics(file_result, extension)

      has_error =
        file_result == "No se encontraron resultados para este archivo" ||
        String.contains?(file_result, "• Estado: error") ||
        String.contains?(file_result, "• Estado: parcial")

      is_partial = String.contains?(file_result, "• Estado: parcial")

      status_class =
        cond do
          not has_error -> "badge-success"
          is_partial    -> "badge-warning"
          true          -> "badge-error"
        end

      status_text =
        cond do
          not has_error -> "Éxito"
          is_partial    -> "Parcial"
          true          -> "Error"
        end

      %{
        name:         file,
        extension:    extension,
        details:      file_result,
        metrics:      metrics,
        has_error:    has_error,
        status_class: status_class,
        status_text:  status_text
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Helpers de sección de archivo
  # ---------------------------------------------------------------------------

  def extract_file_section(report, file) do
    pattern = ~r/\[#{Regex.escape(file)}\].*?(?=\n\[|\Z)/s

    case Regex.run(pattern, report) do
      [match] -> String.trim(match)
      nil     -> "No se encontraron resultados para este archivo"
    end
  end

  def extract_metrics(file_result, extension) do
    base = %{
      total_lines:    extract_value(file_result, ~r/Total líneas: (\d+)/) || "",
      debug:          extract_value(file_result, ~r/DEBUG:?\s*(\d+)/)     || "",
      info:           extract_value(file_result, ~r/INFO:?\s*(\d+)/)      || "",
      warn:           extract_value(file_result, ~r/WARN:?\s*(\d+)/)      || "",
      error:          extract_value(file_result, ~r/ERROR:?\s*(\d+)/)     || "",
      fatal:          extract_value(file_result, ~r/FATAL:?\s*(\d+)/)     || "",
      total_users:    extract_value(file_result, ~r/Total usuarios: (\d+)/)    || "",
      active_users:   extract_value(file_result, ~r/Usuarios activos: (\d+)/)  || "",
      total_sessions: extract_value(file_result, ~r/Total sesiones: (\d+)/)    || "",
      valid_records:  extract_value(file_result, ~r/Registros válidos: (\d+)/) || "",
      total_sales:    extract_value(file_result, ~r/Ventas totales: \$([\d\.]+)/) || "",
      unique_products: extract_value(file_result, ~r/Productos únicos: (\d+)/) || ""
    }

    case extension do
      ".log"  -> Map.take(base, [:total_lines, :debug, :info, :warn, :error, :fatal])
      ".json" -> Map.take(base, [:total_users, :active_users, :total_sessions])
      ".csv"  -> Map.take(base, [:valid_records, :total_sales, :unique_products])
      _       -> %{}
    end
  end

  defp extract_value(text, regex) do
    case Regex.run(regex, text) do
      [_, value] -> value
      nil        -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Resumen de ejecución — usado por ExecutionShowLive
  # ---------------------------------------------------------------------------

  def get_execution_summary(execution) do
    {successes, errors} =
      if execution.mode == "benchmark" do
        files_count = execution.files |> String.split(", ") |> length()
        {files_count, 0}
      else
        successes = length(Regex.scan(~r/• Estado: éxito/, execution.result))
        errors    = length(Regex.scan(~r/• Estado: error/, execution.result)) +
                    length(Regex.scan(~r/• Estado: parcial/, execution.result))

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
      total_time:  execution.total_time,
      successes:   successes,
      errors:      errors,
      total_files: successes + errors
    }
  end

  # ---------------------------------------------------------------------------
  # Benchmark — usado por ExecutionShowLive
  # ---------------------------------------------------------------------------

  def extract_benchmark_data(report) when is_binary(report) do
    sequential =
      extract_value(report, ~r/Sequential Mode:\s*(\d+)/i) ||
      extract_value(report, ~r/Secuencial:\s*(\d+)/i)      ||
      extract_value(report, ~r/📈\s*Secuencial:\s*(\d+)/)

    parallel =
      extract_value(report, ~r/Parallel Mode:\s*(\d+)/i) ||
      extract_value(report, ~r/Paralelo:\s*(\d+)/i)      ||
      extract_value(report, ~r/⚡\s*Paralelo:\s*(\d+)/)

    case {sequential, parallel} do
      {seq, par} when not is_nil(seq) and not is_nil(par) ->
        seq_f = if is_binary(seq), do: String.to_integer(seq), else: seq
        par_f = if is_binary(par), do: String.to_integer(par), else: par

        %{
          sequential_ms: seq_f,
          parallel_ms:   par_f
        }

      _ ->
        nil
    end
  end

  def extract_benchmark_data(_), do: nil

  # ---------------------------------------------------------------------------
  # Helpers de presentación — usados por templates y LiveViews
  # ---------------------------------------------------------------------------

  def file_icon(extension) do
    case extension do
      ".csv"  -> "📊"
      ".json" -> "📋"
      ".log"  -> "📝"
      _       -> "📄"
    end
  end

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

  def format_datetime(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  def format_date(datetime),     do: Calendar.strftime(datetime, "%d/%m/%Y")
  def format_time(datetime),     do: Calendar.strftime(datetime, "%H:%M")
end
