defmodule FileProcessorWeb.ProcessingController do
  use FileProcessorWeb, :controller

  alias ProcesadorArchivos.CoreAdapter
  alias FileProcessor.Executions
  alias FileProcessor.Repo

  @allowed_extensions [".csv", ".json", ".log"]

  # ==========================================
  # FORMULARIO
  # ==========================================
  def new(conn, _params) do
    render(conn, :new)
  end

  # ==========================================
  # PROCESAMIENTO
  # ==========================================
  def create(conn, %{"files" => uploads, "mode" => mode}) do
    cond do
      uploads == [] ->
        conn
        |> put_flash(:error, "Debes seleccionar al menos un archivo")
        |> redirect(to: ~p"/processing")

      has_invalid_extensions?(uploads) ->
        conn
        |> put_flash(:error, "Solo se permiten archivos CSV, JSON o LOG")
        |> redirect(to: ~p"/processing")

      true ->
        process_files(conn, uploads, mode)
    end
  end

  # ==========================================
  # VALIDACIÓN DE EXTENSIONES
  # ==========================================
  defp has_invalid_extensions?(uploads) do
    uploads
    |> Enum.map(&String.downcase(&1.filename))
    |> Enum.any?(fn filename ->
      not Enum.any?(@allowed_extensions, &String.ends_with?(filename, &1))
    end)
  end

  # ==========================================
  # PROCESAMIENTO INTERNO
  # ==========================================
  defp process_files(conn, uploads, mode) do
    start_time = System.monotonic_time(:millisecond)

    upload_dir = Path.join(:code.priv_dir(:file_processor), "uploads")
    File.mkdir_p!(upload_dir)

    # Copiar archivos con su nombre real
    saved_paths =
      Enum.map(uploads, fn %Plug.Upload{path: temp_path, filename: filename} ->
        destination = Path.join(upload_dir, filename)
        File.cp!(temp_path, destination)
        destination
      end)

    # SNAPSHOT ANTES DEL PROCESAMIENTO
    # ==========================================
    output_root = Path.join(File.cwd!(), "output")
    File.mkdir_p!(output_root)

    existing_error_files =
      Path.wildcard(Path.join(output_root, "report_errores_*"))

    # Procesar según el modo
    result_data =
      case mode do
        "sequential" ->
          {:ok, CoreAdapter.process_sequential(saved_paths)}

        "parallel" ->
          case CoreAdapter.process_parallel(saved_paths) do
            %{results: results, total_time: time, successes: ok, errors: err} ->
              {:ok,
               %{
                 type: "parallel",
                 results: results,
                 total_time: time,
                 successes: ok,
                 errors: err
               }}

            other ->
              {:ok, %{type: "parallel", result: other}}
          end

        "benchmark" ->
          CoreAdapter.run_benchmark(saved_paths)

        _ ->
          {:error, "Modo inválido"}
      end

    total_time = System.monotonic_time(:millisecond) - start_time

    files_string =
      uploads
      |> Enum.map(& &1.filename)
      |> Enum.join(", ")

    formatted_result = build_report(result_data, mode, total_time)

    # Determinar contenido real del reporte
    full_result =
      case {mode, result_data} do
        {"benchmark", {:ok, %{full_report: full}}} -> full
        _ -> formatted_result
      end

    timestamp =
      DateTime.utc_now()
      |> DateTime.to_iso8601()
      |> String.replace(":", "-")

    filename =
      case mode do
        "benchmark" -> "report_benchmark_#{timestamp}.txt"
        "parallel" -> "report_parallel_#{timestamp}.txt"
        _ -> "report_sequential_#{timestamp}.txt"
      end

    file_path = Path.join(output_root, filename)

    File.write!(file_path, full_result)

    # SNAPSHOT DESPUÉS DEL PROCESAMIENTO
    # ==========================================
    new_error_files =
      Path.wildcard(Path.join(output_root, "report_errores_*"))
      |> Enum.reject(&(&1 in existing_error_files))

    # Guardar ejecución
    case Executions.create_execution(%{
           timestamp: DateTime.utc_now(),
           files: files_string,
           mode: mode,
           total_time: total_time,
           result: full_result,
           status:
             if String.contains?(full_result, "❌") or
                  String.contains?(full_result, "Error") do
               "partial"
             else
               "success"
             end,
           report_path: file_path
         }) do
      {:ok, execution} ->
        execution_dir =
          Path.join(output_root, "execution_#{execution.id}")

        File.mkdir_p!(execution_dir)

        # Mover reporte principal
        new_report_path =
          Path.join(execution_dir, Path.basename(file_path))

        File.rename!(file_path, new_report_path)

        # Mover los errores generados en esta ejecución
        Enum.each(new_error_files, fn file ->
          File.rename!(file, Path.join(execution_dir, Path.basename(file)))
        end)

        # Actualizar ruta en BD
        Executions.update_execution(execution, %{
          report_path: new_report_path
        })

        redirect(conn, to: ~p"/executions/#{execution.id}")

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "ERROR AL GUARDAR")

        conn
        |> put_flash(:error, "Error al guardar la ejecución")
        |> redirect(to: ~p"/processing")
    end
  end

  # ==========================================
  # GUARDADO EN BASE DE DATOS
  # ==========================================
  defp save_execution(conn, files_string, mode, total_time, result_text, file_path) do
    status =
      if String.contains?(result_text, "❌") or
           String.contains?(result_text, "Error"),
         do: "partial",
         else: "success"

    case Executions.create_execution(%{
           timestamp: DateTime.utc_now(),
           files: files_string,
           mode: mode,
           total_time: total_time,
           result: result_text,
           status: status,
           report_path: file_path
         }) do
      {:ok, execution} ->
        execution_dir = Path.join(File.cwd!(), "output/execution_#{execution.id}")
        File.mkdir_p!(execution_dir)

        # Mover el archivo generado a su carpeta
        new_report_path =
          Path.join(execution_dir, Path.basename(file_path))

        File.rename!(file_path, new_report_path)

        # Actualizar el report_path en BD
        Executions.update_execution(execution, %{
          report_path: new_report_path
        })

        redirect(conn, to: ~p"/executions/#{execution.id}")

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "ERROR AL GUARDAR")

        conn
        |> put_flash(:error, "Error al guardar la ejecución")
        |> redirect(to: ~p"/processing")
    end
  end

  def update_execution(execution, attrs) do
    execution
    |> Execution.changeset(attrs)
    |> Repo.update()
  end

  # ==========================================
  # CONSTRUCCIÓN DEL REPORTE
  # ==========================================

  defp build_report({:ok, data}, mode, total_time) do
    case mode do
      "benchmark" ->
        case data do
          %{summary: summary} -> summary
          _ -> CoreAdapter.extract_benchmark_summary({:ok, data})
        end

      "parallel" when is_map(data) ->
        """
        =====================================
        MODO: PARALLEL
        =====================================

        ⏱️  Tiempo total: #{total_time} ms
        ✅ Exitosos: #{Map.get(data, :successes, 0)}
        ❌ Errores:   #{Map.get(data, :errors, 0)}

        Resultados por archivo:
        #{extract_parallel_results(data[:results])}
        """

      "sequential" ->
        """
        =====================================
        MODO: SEQUENTIAL
        =====================================

        ⏱️  Tiempo total: #{total_time} ms

        Resultados:
        #{extract_sequential_results(data)}
        """

      _ ->
        inspect(data, pretty: true)
    end
  end

  defp build_report({:error, reason}, _mode, _total_time) do
    """
    =====================================
    ❌ ERROR EN PROCESAMIENTO
    =====================================

    #{reason}
    """
  end

  defp build_report(data, mode, total_time) do
    """
    =====================================
    MODO: #{String.upcase(mode)}
    =====================================

    Tiempo total: #{total_time} ms

    Resultado:
    #{inspect(data, pretty: true, limit: :infinity)}
    """
  end

  # ==========================================
  # EXTRACTORES ESPECÍFICOS POR MODO
  # ==========================================

  defp extract_sequential_results(results) when is_list(results) do
    Enum.map_join(results, "\n", fn result ->
      case result do
        %{archivo: file, estado: estado, tipo_archivo: tipo} = full_result ->
          """
          [#{file}] - #{String.upcase(Atom.to_string(tipo))}
          ═══════════════════════════════
          • Estado: #{estado}
          #{format_sequential_detalles(full_result)}
          """

        other ->
          "  • #{inspect(other)}"
      end
    end)
  end

  defp extract_sequential_results(_), do: "  No hay resultados detallados"

  defp extract_parallel_results(results) when is_list(results) do
    Enum.map_join(results, "\n", fn result ->
      case result do
        %{status: status, type: type, file_name: file} = full_result ->
          """
          [#{file}] - #{String.upcase(Atom.to_string(type))}
          ═══════════════════════════════
          • Estado: #{status}
          #{format_parallel_metrics(full_result)}
          """

        other ->
          "  • #{inspect(other)}"
      end
    end)
  end

  defp extract_parallel_results(_), do: ""

  defp format_sequential_detalles(result) do
    case Map.get(result, :tipo_archivo) do
      :csv ->
        detalles = Map.get(result, :detalles, %{})

        """
        • Registros válidos: #{Map.get(detalles, :lineas_validas, 0)}
        • Registros inválidos: #{Map.get(detalles, :lineas_invalidas, 0)}
        • Total líneas: #{Map.get(detalles, :total_lineas, 0)}
        • Éxito: #{Map.get(detalles, :porcentaje_exito, 0)}%
        """

      :json ->
        detalles = Map.get(result, :detalles, %{})

        """
        • Total usuarios: #{Map.get(detalles, :total_usuarios, 0)}
        • Usuarios activos: #{Map.get(detalles, :usuarios_activos, 0)}
        • Total sesiones: #{Map.get(detalles, :total_sesiones, 0)}
        """

      :log ->
        detalles = Map.get(result, :detalles, %{})
        niveles = Map.get(detalles, :distribucion_niveles, %{})

        """
        • Líneas válidas: #{Map.get(result, :lineas_procesadas, 0)}
        • Líneas inválidas: #{Map.get(result, :lineas_con_error, 0)}
        • Total líneas: #{Map.get(detalles, :total_lineas, 0)}

        Distribución:
          • DEBUG: #{Map.get(niveles, :debug, 0)}
          • INFO:  #{Map.get(niveles, :info, 0)}
          • WARN:  #{Map.get(niveles, :warn, 0)}
          • ERROR: #{Map.get(niveles, :error, 0)}
          • FATAL: #{Map.get(niveles, :fatal, 0)}
        """

      _ ->
        inspect(result, pretty: true)
    end
  end

  defp format_parallel_metrics(result) do
    case Map.get(result, :type) do
      :csv ->
        """
        • Registros válidos: #{Map.get(result, :valid_records, 0)}
        • Productos únicos: #{Map.get(result, :unique_products, 0)}
        • Ventas totales: $#{Map.get(result, :total_sales, 0)}
        """

      :json ->
        """
        • Total usuarios: #{Map.get(result, :total_users, 0)}
        • Usuarios activos: #{Map.get(result, :active_users, 0)}
        • Total sesiones: #{Map.get(result, :total_sessions, 0)}
        """

      :log ->
        """
        • Líneas totales: #{Map.get(result, :total_lines, 0)}
        • Distribución:
            DEBUG(#{Map.get(result, :debug, 0)}),
            INFO(#{Map.get(result, :info, 0)}),
            WARN(#{Map.get(result, :warn, 0)}),
            ERROR(#{Map.get(result, :error, 0)}),
            FATAL(#{Map.get(result, :fatal, 0)})
        """

      _ ->
        ""
    end
  end
end
