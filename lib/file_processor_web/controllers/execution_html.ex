defmodule FileProcessorWeb.ExecutionHTML do
  use FileProcessorWeb, :html

  embed_templates "execution_html/*"

  @doc """
  Parsea el resultado de la ejecución para mostrar en formato HTML
  """
  def parse_execution_files(execution) do
    files = String.split(execution.files, ", ")

    Enum.map(files, fn file ->
      extension = Path.extname(file)

      # Extraer la sección del archivo usando el formato [archivo] - TIPO
      file_result = extract_file_section(execution.result, file)

      # Extraer métricas básicas
      metrics = extract_metrics(file_result, extension)

      # Determinar si el archivo tuvo éxito
      has_error = file_result == "No se encontraron resultados para este archivo" ||
                  String.contains?(file_result, "❌") ||
                  String.contains?(file_result, "Error")

      status_class = if has_error, do: "badge-warning", else: "badge-success"
      status_text = if has_error, do: "Parcial", else: "Éxito"

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
      case Regex.run(~r/✅ Exitosos: (\d+).*❌ Errores:\s+(\d+)/s, execution.result) do
        [_, s, e] -> {String.to_integer(s), String.to_integer(e)}
        nil -> {0, 0}
      end

    %{
      total_time: total_time,
      successes: successes,
      errors: errors,
      total_files: successes + errors
    }
  end
end
