defmodule FileProcessorWeb.ProcessingController do
  use FileProcessorWeb, :controller

  alias ProcesadorArchivos.CoreAdapter
  alias FileProcessor.Executions

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

    file_paths =
      Enum.map(uploads, fn %Plug.Upload{path: path} -> path end)

    result_data =
      case mode do
        "sequential" -> CoreAdapter.process_sequential(file_paths)
        "parallel" -> CoreAdapter.process_parallel(file_paths)
        "benchmark" -> CoreAdapter.run_benchmark(file_paths)
        _ -> {:error, "Modo inválido"}
      end

    total_time = System.monotonic_time(:millisecond) - start_time

    files_string =
      uploads
      |> Enum.map(& &1.filename)
      |> Enum.join(", ")

    formatted_result = build_report(result_data, mode, total_time)

    save_execution(conn, files_string, mode, total_time, formatted_result)
  end

  # ==========================================
  # GUARDADO EN BASE DE DATOS
  # ==========================================
  defp save_execution(conn, files_string, mode, total_time, formatted_result) do
    case Executions.create_execution(%{
           timestamp: DateTime.utc_now(),
           files: files_string,
           mode: mode,
           total_time: total_time,
           result: formatted_result
         }) do
      {:ok, execution} ->
        IO.inspect(execution, label: "EJECUCIÓN GUARDADA")
        redirect(conn, to: ~p"/executions/#{execution.id}")

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "ERROR AL GUARDAR")

        conn
        |> put_flash(:error, "Error al guardar la ejecución")
        |> redirect(to: ~p"/processing")
    end
  end

  # ==========================================
  # CONSTRUCCIÓN DEL REPORTE
  # ==========================================
  defp build_report({:error, reason}, _mode, _time) do
    """
    =====================================
    ERROR EN PROCESAMIENTO
    =====================================

    #{inspect(reason)}
    """
  end

  defp build_report(result, "parallel", total_time) when is_map(result) do
    """
    =====================================
    MODO: PARALLEL
    =====================================

    Tiempo total: #{total_time} ms
    Procesados exitosamente: #{Map.get(result, :successes, 0)}
    Errores: #{Map.get(result, :errors, 0)}
    """
  end

  defp build_report(result, "sequential", total_time) do
    """
    =====================================
    MODO: SEQUENTIAL
    =====================================

    Tiempo total: #{total_time} ms

    Resultado detallado:
    #{inspect(result, pretty: true, limit: :infinity)}
    """
  end

  defp build_report(result, "benchmark", total_time) do
    """
    =====================================
    MODO: BENCHMARK
    =====================================

    Tiempo total ejecución: #{total_time} ms

    Comparativa:
    #{inspect(result, pretty: true, limit: :infinity)}
    """
  end

  defp build_report(result, _mode, _time) do
    inspect(result, pretty: true, limit: :infinity)
  end
end
