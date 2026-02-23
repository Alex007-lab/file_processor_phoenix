defmodule FileProcessorWeb.ProcessingController do
  use FileProcessorWeb, :controller

  alias ProcesadorArchivos.CoreAdapter
  alias FileProcessor.Executions

  @allowed_extensions [".csv", ".json", ".log"]
  @output_dir "output"

  def new(conn, _params) do
    render(conn, :new)
  end

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

  defp has_invalid_extensions?(uploads) do
    uploads
    |> Enum.map(&String.downcase(&1.filename))
    |> Enum.any?(fn filename ->
      not Enum.any?(@allowed_extensions, &String.ends_with?(filename, &1))
    end)
  end

  defp process_files(conn, uploads, mode) do
    start_time = System.monotonic_time(:millisecond)

    upload_dir = Path.join(:code.priv_dir(:file_processor), "uploads")
    File.mkdir_p!(upload_dir)

    saved_paths =
      Enum.map(uploads, fn %Plug.Upload{path: temp_path, filename: filename} ->
        destination = Path.join(upload_dir, filename)
        File.cp!(temp_path, destination)
        destination
      end)

    # Limpiar archivos temporales antiguos (opcional)
    cleanup_old_output_files()

    # Procesar según el modo
    result_data =
      case mode do
        "sequential" ->
          results = CoreAdapter.process_sequential(saved_paths)
          total_time = System.monotonic_time(:millisecond) - start_time
          report = build_single_report(results, mode, total_time)
          %{report: report, results: results, total_time: total_time}

        "parallel" ->
          case CoreAdapter.process_parallel(saved_paths) do
            %{results: results, successes: successes, errors: errors} = full_result ->
              total_time = System.monotonic_time(:millisecond) - start_time
              report = build_parallel_report(full_result, total_time)

              %{
                report: report,
                results: results,
                total_time: total_time,
                successes: successes,
                errors: errors
              }
          end

        "benchmark" ->
          case CoreAdapter.run_benchmark(saved_paths) do
            {:ok, data} ->
              total_time = System.monotonic_time(:millisecond) - start_time
              report = build_benchmark_report(data, total_time)
              %{report: report, benchmark_data: data, total_time: total_time}

            error ->
              %{report: "Error en benchmark: #{inspect(error)}", total_time: 0}
          end
      end

    files_string =
      uploads
      |> Enum.map(& &1.filename)
      |> Enum.join(", ")

    # Limpiar archivos temporales de output después de procesar
    cleanup_temp_files()

    # Guardar ejecución
    save_execution(conn, files_string, mode, result_data)
  end

  # Construye UN SOLO reporte para secuencial
  # Reemplaza la función build_single_report en processing_controller.ex

  defp build_single_report(results, mode, total_time) do
    # Contar correctamente los éxitos y errores
    successes =
      Enum.count(results, fn result ->
        case result do
          %{status: :success} -> true
          %{estado: :completo} -> true
          _ -> false
        end
      end)

    errors = length(results) - successes

    files_content =
      Enum.map_join(results, "\n\n", fn result ->
        # Verificar si hay reporte de errores adicional
        error_report = Map.get(result, :reporte_contenido, "")

        base_content =
          case result do
            %{
              type: :csv,
              file_name: file,
              valid_records: valid,
              total_sales: sales,
              unique_products: unique
            } ->
              """
              [#{file}] - CSV
              ═══════════════════════════════
              • Estado: éxito
              • Registros válidos: #{valid}
              • Productos únicos: #{unique}
              • Ventas totales: $#{:erlang.float_to_binary(sales, decimals: 2)}
              """

            %{
              type: :json,
              file_name: file,
              total_users: users,
              active_users: active,
              total_sessions: sessions
            } ->
              """
              [#{file}] - JSON
              ═══════════════════════════════
              • Estado: éxito
              • Total usuarios: #{users}
              • Usuarios activos: #{active}
              • Total sesiones: #{sessions}
              """

            %{
              type: :log,
              file_name: file,
              total_lines: total,
              debug: debug,
              info: info,
              warn: warn,
              error: error,
              fatal: fatal
            } ->
              """
              [#{file}] - LOG
              ═══════════════════════════════
              • Estado: éxito
              • Total líneas: #{total}
              • Distribución:
                  DEBUG: #{debug}
                  INFO:  #{info}
                  WARN:  #{warn}
                  ERROR: #{error}
                  FATAL: #{fatal}
              """

            # Formato del core (con :archivo y :estado)
            %{archivo: file, estado: estado, tipo_archivo: tipo} = full_result ->
              estado_text = if estado == :completo, do: "éxito", else: "error"

              case tipo do
                :csv ->
                  """
                  [#{file}] - CSV
                  ═══════════════════════════════
                  • Estado: #{estado_text}
                  • Registros válidos: #{get_in(full_result, [:detalles, :lineas_validas]) || 0}
                  • Registros inválidos: #{get_in(full_result, [:detalles, :lineas_invalidas]) || 0}
                  • Total líneas: #{get_in(full_result, [:detalles, :total_lineas]) || 0}
                  • Éxito: #{get_in(full_result, [:detalles, :porcentaje_exito]) || 0}%
                  """

                :json ->
                  """
                  [#{file}] - JSON
                  ═══════════════════════════════
                  • Estado: #{estado_text}
                  • Total usuarios: #{get_in(full_result, [:detalles, :total_usuarios]) || 0}
                  • Usuarios activos: #{get_in(full_result, [:detalles, :usuarios_activos]) || 0}
                  • Total sesiones: #{get_in(full_result, [:detalles, :total_sesiones]) || 0}
                  """

                :log ->
                  niveles = get_in(full_result, [:detalles, :distribucion_niveles]) || %{}

                  """
                  [#{file}] - LOG
                  ═══════════════════════════════
                  • Estado: #{estado_text}
                  • Líneas válidas: #{Map.get(full_result, :lineas_procesadas, 0)}
                  • Líneas inválidas: #{Map.get(full_result, :lineas_con_error, 0)}
                  • Total líneas: #{get_in(full_result, [:detalles, :total_lineas]) || 0}

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

            %{file_name: file, status: :error, error: reason} ->
              """
              [#{file}] - ERROR
              ═══════════════════════════════
              • Estado: error
              • Razón: #{reason}
              """

            other ->
              inspect(other, pretty: true)
          end

        # Si hay reporte de error adicional, agregarlo
        if error_report != "" do
          base_content <> "\n\n" <> error_report
        else
          base_content
        end
      end)

    """
    =====================================
    MODO: #{String.upcase(mode)}
    =====================================

    ⏱️  Tiempo total: #{total_time} ms
    ✅ Exitosos: #{successes}
    ❌ Errores:   #{errors}

    Resultados por archivo:
    #{files_content}
    """
  end

  # Construye UN SOLO reporte para paralelo
  defp build_parallel_report(
         %{results: results, successes: successes, errors: errors},
         total_time_global
       ) do
    files_content =
      Enum.map_join(results, "\n\n", fn result ->
        # Verificar si hay reporte de errores adicional
        error_report = Map.get(result, :reporte_contenido, "")

        base_content =
          case result do
            %{
              status: :success,
              type: :csv,
              file_name: file,
              valid_records: valid,
              total_sales: sales,
              unique_products: unique
            } ->
              """
              [#{file}] - CSV
              ═══════════════════════════════
              • Estado: éxito
              • Registros válidos: #{valid}
              • Productos únicos: #{unique}
              • Ventas totales: $#{:erlang.float_to_binary(sales, decimals: 2)}
              """

            %{
              status: :success,
              type: :json,
              file_name: file,
              total_users: users,
              active_users: active,
              total_sessions: sessions
            } ->
              """
              [#{file}] - JSON
              ═══════════════════════════════
              • Estado: éxito
              • Total usuarios: #{users}
              • Usuarios activos: #{active}
              • Total sesiones: #{sessions}
              """

            %{
              status: :success,
              type: :log,
              file_name: file,
              total_lines: total,
              debug: debug,
              info: info,
              warn: warn,
              error: error,
              fatal: fatal
            } ->
              """
              [#{file}] - LOG
              ═══════════════════════════════
              • Estado: éxito
              • Total líneas: #{total}
              • Distribución:
                  DEBUG: #{debug}
                  INFO:  #{info}
                  WARN:  #{warn}
                  ERROR: #{error}
                  FATAL: #{fatal}
              """

            %{status: :error, file_name: file, error: reason} ->
              """
              [#{file}] - ERROR
              ═══════════════════════════════
              • Estado: error
              • Razón: #{reason}
              """

            other ->
              inspect(other, pretty: true)
          end

        # Si hay reporte de error adicional, agregarlo
        if error_report != "" do
          base_content <> "\n\n" <> error_report
        else
          base_content
        end
      end)

    """
    =====================================
    MODO: PARALELO
    =====================================

    ⏱️  Tiempo total: #{total_time_global} ms
    ✅ Exitosos: #{successes}
    ❌ Errores:   #{errors}

    Resultados por archivo:
    #{files_content}
    """
  end

  # Construye UN SOLO reporte para benchmark
  defp build_benchmark_report(data, total_time) do
    summary = CoreAdapter.extract_benchmark_summary({:ok, data})

    """
    #{summary}

    ⏱️  Tiempo total de benchmark: #{total_time} ms

    Reporte completo:
    #{Map.get(data, :full_report, "No disponible")}
    """
  end

  # Guarda la ejecución con UN SOLO reporte
  defp save_execution(conn, files_string, mode, result_data) do
    report_text = result_data.report

    # Determinar si hay errores REALES basado en el contenido
    has_errors =
      String.contains?(report_text, "❌ Errores:   0") == false or
        String.contains?(report_text, "• Estado: error") or
        (String.contains?(report_text, "❌") && !String.contains?(report_text, "❌ Errores:   0"))

    status = if has_errors, do: "partial", else: "success"

    attrs = %{
      timestamp: DateTime.utc_now(),
      files: files_string,
      mode: mode,
      total_time: Map.get(result_data, :total_time, 0),
      result: report_text,
      status: status,
      report_path: nil
    }

    case Executions.create_execution(attrs) do
      {:ok, execution} ->
        redirect(conn, to: ~p"/executions/#{execution.id}")

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "ERROR AL GUARDAR")

        conn
        |> put_flash(:error, "Error al guardar la ejecución")
        |> redirect(to: ~p"/processing")
    end
  end

  # Limpia archivos temporales de output
  defp cleanup_temp_files do
    Task.start(fn ->
      case File.ls(@output_dir) do
        {:ok, files} ->
          now = DateTime.utc_now()

          Enum.each(files, fn file ->
            path = Path.join(@output_dir, file)

            if String.ends_with?(file, ".txt") do
              case File.stat(path) do
                {:ok, %{mtime: mtime}} ->
                  mtime_naive = NaiveDateTime.from_erl!(mtime)
                  mtime_datetime = DateTime.from_naive!(mtime_naive, "Etc/UTC")

                  if DateTime.diff(now, mtime_datetime) > 300 do
                    File.rm(path)
                  end

                _ ->
                  :ok
              end
            end
          end)

        _ ->
          :ok
      end
    end)
  end

  defp cleanup_old_output_files do
    case File.ls(@output_dir) do
      {:ok, files} ->
        now = DateTime.utc_now()

        Enum.each(files, fn file ->
          path = Path.join(@output_dir, file)

          if String.ends_with?(file, ".txt") do
            case File.stat(path) do
              {:ok, %{mtime: mtime}} ->
                mtime_naive = NaiveDateTime.from_erl!(mtime)
                mtime_datetime = DateTime.from_naive!(mtime_naive, "Etc/UTC")

                if DateTime.diff(now, mtime_datetime) > 3600 do
                  File.rm(path)
                end

              _ ->
                :ok
            end
          end
        end)

      _ ->
        :ok
    end
  end
end
