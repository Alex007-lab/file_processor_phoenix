defmodule FileProcessorWeb.ProcessingController do
  use FileProcessorWeb, :controller

  alias ProcesadorArchivos.CoreAdapter
  alias FileProcessor.Executions
  alias FileProcessor.ReportBuilder

  @allowed_extensions [".csv", ".json", ".log"]

  # ---------------------------------------------------------------------------
  # Acciones
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Privadas — procesamiento
  # ---------------------------------------------------------------------------

  defp process_files(conn, uploads, mode) do
    saved_paths = save_uploads(uploads)
    start_time  = System.monotonic_time(:millisecond)

    {report, status} =
      case mode do
        "sequential" ->
          results    = CoreAdapter.process_sequential(saved_paths)
          total_time = elapsed(start_time)
          report     = ReportBuilder.build_sequential(results, total_time)
          status     = derive_status(results)
          {report, status}

        "parallel" ->
          parallel_result = CoreAdapter.process_parallel(saved_paths)
          total_time      = elapsed(start_time)
          report          = ReportBuilder.build_parallel(parallel_result, total_time)
          status          = derive_status(parallel_result.results)
          {report, status}

        "benchmark" ->
          case CoreAdapter.run_benchmark(saved_paths) do
            {:ok, data} ->
              total_time = elapsed(start_time)
              report     = ReportBuilder.build_benchmark(data, total_time)
              {report, "success"}

            {:error, reason} ->
              {"Error en benchmark: #{reason}", "partial"}
          end
      end

    files_string = uploads |> Enum.map(& &1.filename) |> Enum.join(", ")
    save_execution(conn, files_string, mode, report, elapsed(start_time), status)
  end

  # Copia los uploads a priv/uploads y devuelve sus rutas definitivas.
  defp save_uploads(uploads) do
    upload_dir = Path.join(:code.priv_dir(:file_processor), "uploads")
    File.mkdir_p!(upload_dir)

    Enum.map(uploads, fn %Plug.Upload{path: temp_path, filename: filename} ->
      destination = Path.join(upload_dir, filename)
      File.cp!(temp_path, destination)
      destination
    end)
  end

  # ---------------------------------------------------------------------------
  # Privadas — persistencia
  # ---------------------------------------------------------------------------

  defp save_execution(conn, files_string, mode, report, total_time, status) do
    attrs = %{
      timestamp:   DateTime.utc_now(),
      files:       files_string,
      mode:        mode,
      total_time:  total_time,
      result:      report,
      status:      status,
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

  # ---------------------------------------------------------------------------
  # Privadas — utilidades
  # ---------------------------------------------------------------------------

  defp has_invalid_extensions?(uploads) do
    Enum.any?(uploads, fn upload ->
      ext = upload.filename |> String.downcase() |> Path.extname()
      ext not in @allowed_extensions
    end)
  end

  defp elapsed(start_time) do
    System.monotonic_time(:millisecond) - start_time
  end

  # Deriva el status de la ejecución usando directamente el campo :status
  # que devuelve el core, sin parsear el texto del reporte.
  #   :success / :completo → todos exitosos → "success"
  #   cualquier otro       → al menos uno falló → "partial"
  defp derive_status(results) do
    all_success =
      Enum.all?(results, fn result ->
        result[:status] == :success or result[:estado] == :completo
      end)

    if all_success, do: "success", else: "partial"
  end
end
