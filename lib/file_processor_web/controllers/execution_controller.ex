defmodule FileProcessorWeb.ExecutionController do
  use FileProcessorWeb, :controller

  alias FileProcessor.Executions

  # ==========================================
  # ACCIONES DEL CONTROLADOR
  # ==========================================

  def index(conn, params) do
    # Obtener ejecuciones según filtro
    executions = get_filtered_executions(params)

    # Obtener estadísticas para el dashboard
    stats = Executions.get_statistics()

    render(conn, :index,
      executions: executions,
      stats: stats,
      current_filter: params["mode"] || "all"
    )
  end

  def show(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)
    render(conn, :show, execution: execution)
  end

  def download(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)

    # Generar nombre de archivo basado en el modo y fecha
    date = Calendar.strftime(execution.timestamp, "%Y%m%d_%H%M%S")
    filename = "#{execution.mode}_report_#{date}.txt"

    # El resultado YA TIENE el formato del core, solo descargarlo
    send_download(conn, {:binary, execution.result},
      filename: filename,
      content_type: "text/plain"
    )
  end

  def delete(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)
    {:ok, _execution} = Executions.delete_execution(execution)

    conn
    |> put_flash(:info, "Ejecución eliminada exitosamente")
    |> redirect(to: ~p"/executions")
  end

  def delete_all(conn, _params) do
    Executions.delete_all_executions()

    conn
    |> put_flash(:info, "Todo el historial ha sido eliminado")
    |> redirect(to: ~p"/executions")
  end

  # ==========================================
  # FUNCIONES PRIVADAS DEL CONTROLADOR
  # ==========================================

  defp get_filtered_executions(params) do
    case params["mode"] do
      "sequential" -> Executions.list_executions_by_mode("sequential")
      "parallel" -> Executions.list_executions_by_mode("parallel")
      "benchmark" -> Executions.list_executions_by_mode("benchmark")
      "today" -> filter_today()
      "week" -> filter_this_week()
      _ -> Executions.list_executions()
    end
  end

  defp filter_today do
    today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00])
    today_end = Date.utc_today() |> DateTime.new!(~T[23:59:59])
    Executions.list_executions_by_date_range(today_start, today_end)
  end

  defp filter_this_week do
    today = Date.utc_today()
    start_of_week = Date.beginning_of_week(today)
    end_of_week = Date.end_of_week(today)

    week_start = DateTime.new!(start_of_week, ~T[00:00:00])
    week_end = DateTime.new!(end_of_week, ~T[23:59:59])

    Executions.list_executions_by_date_range(week_start, week_end)
  end

  # ==========================================
  # HELPERS PARA LAS VISTAS (EXPORTADOS)
  # ==========================================

  @doc """
  Extrae la sección de un archivo específico del reporte completo.
  """
  def extract_file_section(report, file) do
    # Para modo secuencial (formato con • %{archivo: "nombre"})
    pattern1 = ~r/• %\{[^\}]*archivo: "#{Regex.escape(file)}"[^\}]*\}/

    # Para modo secuencial (formato con [nombre] - TIPO)
    pattern2 = ~r/\[#{Regex.escape(file)}\].*?(?=\n\[|\Z)/s

    # Para modo paralelo (formato con mapa de resultados)
    pattern3 = ~r/"#{Regex.escape(file)}" => %\{[^\}]+\}/

    # Para el formato del reporte descargable
    pattern4 = ~r/\[#{Regex.escape(file)}\] - [A-Z]+\n═+[^\n]+\n(?:• [^\n]+\n)+/

    result = cond do
      # Buscar en formato secuencial (patrón 1)
      match = Regex.run(pattern1, report) ->
        match |> hd() |> format_sequential_match()

      # Buscar en formato secuencial (patrón 2)
      match = Regex.run(pattern2, report) ->
        match |> hd() |> String.trim()

      # Buscar en formato paralelo
      match = Regex.run(pattern3, report) ->
        match |> hd() |> format_parallel_match()

      # Buscar en formato de reporte descargable
      match = Regex.run(pattern4, report) ->
        match |> hd() |> String.trim()

      true ->
        # Último intento: buscar cualquier mención del archivo
        lines = String.split(report, "\n")
        relevant_lines = Enum.filter(lines, fn line ->
          String.contains?(line, file) and
          not String.contains?(line, "No se encontraron resultados")
        end)

        if Enum.empty?(relevant_lines) do
          "No se encontraron resultados para este archivo"
        else
          Enum.join(relevant_lines, "\n")
        end
    end

    # Asegurar que siempre retornamos un string
    if is_binary(result), do: result, else: inspect(result)
  end

  defp format_sequential_match(match) do
    match
    |> String.replace("• %{", "{\n  ")
    |> String.replace(", ", "\n  ")
    |> String.replace("}", "\n}")
  end

  defp format_parallel_match(match) do
    match
    |> String.split(" => ")
    |> List.last()
    |> String.replace("%{", "{\n  ")
    |> String.replace(", ", "\n  ")
    |> String.replace("}", "\n}")
  end

  @doc """
  Extrae los datos de benchmark del reporte y los devuelve como mapa estructurado.
  """
  def extract_benchmark_data(report) do
    sequential = extract_value(report, ~r/Secuencial:?\s*(\d+)\s*ms/i)
    parallel = extract_value(report, ~r/Paralelo:?\s*(\d+)\s*ms/i)

    if sequential && parallel do
      # Extraer valores del reporte
      improvement = extract_value(report, ~r/Mejora:?\s*([\d.]+)x/i) || sequential / parallel
      time_saved = extract_value(report, ~r/Diferencia:?\s*(\d+)\s*ms/i) || sequential - parallel
      percent = extract_value(report, ~r/Eficiencia:?\s*([\d.]+)%/i) || (1 - parallel / sequential) * 100

      # Determinar dirección de la mejora
      faster_text = if sequential > parallel, do: "⚡ Paralelo más rápido", else: "📋 Secuencial más rápido"

      %{
        sequential_ms: sequential,
        parallel_ms: parallel,
        improvement: Float.round(improvement, 2),
        time_saved: abs(time_saved),
        percent_faster: Float.round(abs(percent), 1),
        faster_mode: faster_text
      }
    end
  end

  @doc """
  Parsea el string de archivos y devuelve una lista con nombres y extensiones.
  """
  def parse_files_string(files_string) do
    files_string
    |> String.split(", ")
    |> Enum.map(fn file ->
      %{
        full_name: file,
        name: Path.basename(file),
        extension: Path.extname(file)
      }
    end)
  end

  @doc """
  Determina el ícono correspondiente según la extensión del archivo.
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
  Determina el color de badge según el modo de procesamiento.
  """
  def mode_badge_color(mode) do
    case mode do
      "sequential" -> "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"
      "parallel" -> "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
      "benchmark" -> "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400"
      _ -> "bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
    end
  end

  @doc """
  Texto amigable para el modo de procesamiento.
  """
  def mode_display_name(mode) do
    case mode do
      "sequential" -> "📋 Secuencial"
      "parallel" -> "⚡ Paralelo"
      "benchmark" -> "📊 Benchmark"
      _ -> mode
    end
  end

  @doc """
  Formatea una fecha para mostrar.
  """
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  end

  @doc """
  Formatea solo la fecha.
  """
  def format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  @doc """
  Formatea solo la hora.
  """
  def format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end

  @doc """
  Formatea un resultado de archivo para mostrar bonito.
  """
  def format_file_result(result_map) when is_map(result_map) do
    tipo = Map.get(result_map, :tipo_archivo, "desconocido")
    archivo = Map.get(result_map, :archivo, "unknown")
    estado = Map.get(result_map, :estado, :desconocido)
    detalles = Map.get(result_map, :detalles, %{})

    case tipo do
      :csv ->
        """
        [#{archivo}] - CSV
        ═══════════════════════════════
        • Estado: #{estado}
        • Registros válidos: #{Map.get(detalles, :lineas_validas, 0)}
        • Registros inválidos: #{Map.get(detalles, :lineas_invalidas, 0)}
        • Total líneas: #{Map.get(detalles, :total_lineas, 0)}
        • Éxito: #{Map.get(detalles, :porcentaje_exito, 0)}%
        """

      :json ->
        """
        [#{archivo}] - JSON
        ═══════════════════════════════
        • Estado: #{estado}
        • Total usuarios: #{Map.get(detalles, :total_usuarios, 0)}
        • Usuarios activos: #{Map.get(detalles, :usuarios_activos, 0)}
        • Total sesiones: #{Map.get(detalles, :total_sesiones, 0)}
        """

      :log ->
        niveles = Map.get(detalles, :distribucion_niveles, %{})
        """
        [#{archivo}] - LOG
        ═══════════════════════════════
        • Estado: #{estado}
        • Líneas válidas: #{Map.get(result_map, :lineas_procesadas, 0)}
        • Líneas inválidas: #{Map.get(result_map, :lineas_con_error, 0)}
        • Total líneas: #{Map.get(detalles, :total_lineas, 0)}

        Distribución:
          • DEBUG: #{Map.get(niveles, :debug, 0)}
          • INFO:  #{Map.get(niveles, :info, 0)}
          • WARN:  #{Map.get(niveles, :warn, 0)}
          • ERROR: #{Map.get(niveles, :error, 0)}
          • FATAL: #{Map.get(niveles, :fatal, 0)}
        """

      _ ->
        inspect(result_map, pretty: true)
    end
  end

  def format_file_result(_), do: "Resultado no disponible"

  @doc """
  Función de depuración para ver qué formato tiene el reporte.
  """
  def debug_report_format(report) do
    lines = String.split(report, "\n") |> Enum.take(20)
    IO.inspect(lines, label: "PRIMERAS 20 LÍNEAS DEL REPORTE")
    report
  end

  # ==========================================
  # FUNCIONES PRIVADAS AUXILIARES
  # ==========================================

  defp extract_value(report, regex) do
    case Regex.run(regex, report) do
      [_, value] ->
        if String.contains?(value, "."),
          do: String.to_float(value),
          else: String.to_integer(value)
      _ -> nil
    end
  end
end 
