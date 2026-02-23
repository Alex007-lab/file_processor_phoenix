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

    benchmark_data =
      if execution.mode == "benchmark" do
        extract_benchmark_data(execution.result)
      else
        nil
      end

    render(conn, :show,
      execution: execution,
      benchmark_data: benchmark_data
    )
  end

  def download(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)

    cond do
      # Si es benchmark → mantener comportamiento actual
      execution.mode == "benchmark" ->
        download_benchmark(conn, execution)

      # Si es secuencial/paralelo y tiene errores
      String.contains?(execution.result, "Error") or
          String.contains?(execution.result, "parcial") ->
        download_error_report(conn, execution)

      # Caso normal → comportamiento actual
      true ->
        download_normal_report(conn, execution)
    end
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

    result =
      cond do
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

          relevant_lines =
            Enum.filter(lines, fn line ->
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
  def extract_benchmark_data(report) when is_binary(report) do
    sequential =
      extract_value(report, ~r/Sequential Mode:\s*(\d+)/i)

    parallel =
      extract_value(report, ~r/Parallel Mode:\s*(\d+)/i)

    case {sequential, parallel} do
      {seq, par} when is_integer(seq) and is_integer(par) ->
        time_saved = seq - par

        percent =
          if seq > 0 do
            (seq - par) / seq * 100
          else
            0.0
          end

        improvement =
          if par > 0 do
            seq / par
          else
            0.0
          end

        %{
          sequential_ms: seq,
          parallel_ms: par,
          improvement: Float.round(improvement, 2),
          time_saved: abs(time_saved),
          percent_faster: Float.round(abs(percent), 1),
          faster_mode:
            cond do
              time_saved > 0 -> "⚡ Paralelo más rápido"
              time_saved < 0 -> "📋 Secuencial más rápido"
              true -> "⚖️ Igual rendimiento"
            end
        }

      _ ->
        nil
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

      _ ->
        nil
    end
  end

  defp safe_float(value) when is_float(value), do: value
  defp safe_float(value) when is_integer(value), do: value * 1.0
  defp safe_float(_), do: 0.0

  # ==========================================
  # DOWNLOAD NORMAL
  # ==========================================
  defp download_normal_report(conn, execution) do
    send_download(conn, {:binary, execution.result},
      filename: "execution_#{execution.id}.txt",
      content_type: "text/plain"
    )
  end

  # ==========================================
  # DOWNLOAD ERROR REPORT
  # ==========================================
  defp download_error_report(conn, execution) do
    execution_dir =
      Path.expand("output/execution_#{execution.id}")

    unless File.exists?(execution_dir) do
      conn
      |> put_flash(:error, "No se encontró la carpeta de esta ejecución")
      |> redirect(to: ~p"/executions/#{execution.id}")
    else
      error_reports =
        Path.wildcard(Path.join(execution_dir, "*.txt"))

      case error_reports do
        [] ->
          conn
          |> put_flash(:error, "No se encontraron reportes de errores")
          |> redirect(to: ~p"/executions/#{execution.id}")

        [single] ->
          send_download(conn, {:file, single},
            filename: Path.basename(single),
            content_type: "text/plain"
          )

        multiple ->
          zip_path = create_error_zip(multiple, execution.id)

          send_download(conn, {:file, zip_path},
            filename: "error_reports_execution_#{execution.id}.zip",
            content_type: "application/zip"
          )
      end
    end
  end

  # ==========================================
  # DOWNLOAD BENCHMARK
  # ==========================================
  defp download_benchmark(conn, execution) do
    send_download(conn, {:binary, execution.result},
      filename: "benchmark_#{execution.id}.txt",
      content_type: "text/plain"
    )
  end

  # ==========================================
  # Compresion de archivos ZIP
  # ==========================================
  defp create_error_zip(files, execution_id) do
    execution_dir =
      Path.expand("output/execution_#{execution_id}")

    File.mkdir_p!(execution_dir)

    zip_path =
      Path.join(execution_dir, "error_reports_execution_#{execution_id}.zip")

    entries =
      Enum.map(files, fn file ->
        {:ok, content} = File.read(file)
        {String.to_charlist(Path.basename(file)), content}
      end)

    case :zip.create(String.to_charlist(zip_path), entries) do
      {:ok, _} ->
        zip_path

      {:error, reason} ->
        IO.inspect(reason, label: "ZIP ERROR")
        raise "No se pudo crear el ZIP"
    end
  end
end
