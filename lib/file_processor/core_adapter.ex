defmodule ProcesadorArchivos.CoreAdapter do
  @moduledoc """
  Adaptador entre Phoenix y el core ProcesadorArchivos.

  Centraliza las llamadas al core para que los controllers y LiveViews
  no dependan directamente de los módulos internos de ProcesadorArchivos.

  El core genera reportes en `output/` automáticamente como parte de su flujo.
  Dado que Phoenix guarda el contenido del reporte en la base de datos,
  los archivos en disco son redundantes. Este módulo los elimina tras cada
  llamada para que `output/` permanezca vacío entre ejecuciones.
  """

  @output_dir "output"

  # ---------------------------------------------------------------------------
  # Procesamiento
  # ---------------------------------------------------------------------------

  @doc """
  Procesa un único archivo usando el parser directo del core.

  Usado por ProcessingLive para procesar archivos de forma individual
  y enviar feedback en tiempo real al cliente.

  Devuelve el mapa estándar del parser:
  `%{type, status, file_name, ...métricas}`.
  """
  def process_file_single(file_path) do
    result = ProcesadorArchivos.process_file(file_path)
    cleanup_output()
    enrich_result(result, file_path)
  end

  @doc """
  Procesa una lista de archivos de forma secuencial usando los parsers directos
  del core (`ProcesadorArchivos.process_file/1`).

  Devuelve una lista de mapas con el formato estándar del parser:
  `%{type, status, file_name, ...métricas específicas por tipo}`.
  """
  def process_sequential(file_paths) do
    results =
      Enum.zip(file_paths, Enum.map(file_paths, &ProcesadorArchivos.process_file/1))
      |> Enum.map(fn {path, result} -> enrich_result(result, path) end)
    cleanup_output()
    results
  end

  @doc """
  Procesa una lista de archivos en paralelo usando el patrón
  Coordinator/Worker del core.

  Devuelve el mapa completo de resultados incluyendo `:results`,
  `:successes`, `:errors`, `:total_time` y `:report_file`.
  """
  def process_parallel(file_paths) do
    result = ProcesadorArchivos.process_parallel(file_paths)
    cleanup_output()
    result
  end

  @doc """
  Ejecuta el benchmark comparativo secuencial vs paralelo.

  Copia los archivos a un directorio temporal para que el core pueda
  recibir una carpeta (que es lo que espera `ProcesadorArchivos.benchmark/2`),
  y limpia el directorio temporal y output/ al finalizar.

  ## Retorna

    - `{:ok, %{full_report, sequential_ms, parallel_ms, improvement, percent_faster}}`
    - `{:error, reason}`
  """
  def run_benchmark([]), do: {:error, "No hay archivos para benchmark"}

  def run_benchmark(file_paths) do
    temp_dir = build_temp_dir()

    try do
      copy_files_to(file_paths, temp_dir)

      case ProcesadorArchivos.benchmark(temp_dir, %{}) do
        result when is_map(result) ->
          {:ok, build_benchmark_result(result)}

        _ ->
          {:error, "Resultado inesperado del benchmark"}
      end
    after
      File.rm_rf(temp_dir)
      cleanup_output()
    end
  end

  # ---------------------------------------------------------------------------
  # ---------------------------------------------------------------------------
  # Privadas — enriquecimiento de resultados
  # ---------------------------------------------------------------------------

  # El core nunca devuelve :error para archivos con datos parcialmente corruptos —
  # simplemente filtra las líneas inválidas y retorna :ok con los registros válidos.
  # Esta función detecta el caso "parcial": el parser tuvo éxito pero hubo líneas
  # que no pudieron procesarse.

  defp enrich_result(%{status: :success, type: :csv} = result, file_path) do
    total_lines = count_data_lines(file_path)
    valid        = Map.get(result, :valid_records, 0)

    if total_lines > 0 and valid < total_lines do
      Map.put(result, :status, :partial)
    else
      result
    end
  end

  defp enrich_result(%{status: :success, type: :json} = result, file_path) do
    # JSON malformado: si el archivo tiene contenido pero las métricas quedan en 0
    # es señal de que el parser no pudo interpretar la estructura correctamente.
    total_users    = Map.get(result, :total_users, 0)
    total_sessions = Map.get(result, :total_sessions, 0)
    file_size      = case File.stat(file_path) do
                       {:ok, %{size: s}} -> s
                       _ -> 0
                     end

    if file_size > 50 and total_users == 0 and total_sessions == 0 do
      Map.put(result, :status, :partial)
    else
      result
    end
  end

  defp enrich_result(%{status: :success, type: :log} = result, file_path) do
    total_lines = count_data_lines(file_path)
    valid        = Map.get(result, :total_lines, 0)

    if total_lines > 0 and valid < total_lines do
      Map.put(result, :status, :partial)
    else
      result
    end
  end

  defp enrich_result(result, _file_path), do: result

  defp count_data_lines(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.drop(1)
        |> Enum.reject(&(String.trim(&1) == ""))
        |> length()
      _ -> 0
    end
  end

  # ---------------------------------------------------------------------------
  # Privadas — limpieza
  # ---------------------------------------------------------------------------

  defp cleanup_output do
    if File.dir?(@output_dir) do
      @output_dir
      |> File.ls!()
      |> Enum.each(fn file ->
        File.rm(Path.join(@output_dir, file))
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Privadas — benchmark
  # ---------------------------------------------------------------------------

  defp build_temp_dir do
    root = Path.join(:code.priv_dir(:file_processor), "benchmark_temp")
    dir  = Path.join(root, "run_#{DateTime.utc_now() |> DateTime.to_unix()}")
    File.mkdir_p!(dir)
    dir
  end

  defp copy_files_to(file_paths, dir) do
    Enum.each(file_paths, fn file ->
      File.cp!(file, Path.join(dir, Path.basename(file)))
    end)
  end

  defp build_benchmark_result(result) do
    %{
      full_report:    read_benchmark_content(result),
      sequential_ms:  Map.get(result, :sequential_ms, 0),
      parallel_ms:    Map.get(result, :parallel_ms, 0),
      improvement:    Map.get(result, :improvement, 0),
      percent_faster: Map.get(result, :percent_faster, 0)
    }
  end

  defp read_benchmark_content(result) do
    cond do
      Map.has_key?(result, :benchmark_content) ->
        result.benchmark_content

      Map.has_key?(result, :benchmark_report) ->
        case File.read(result.benchmark_report) do
          {:ok, content} -> content
          _              -> fallback_content(result)
        end

      true ->
        fallback_content(result)
    end
  end

  defp fallback_content(result) do
    """
    BENCHMARK RESULTS
    ━━━━━━━━━━━━━━━━━━━━━━━━━
    Secuencial: #{Map.get(result, :sequential_ms, 0)} ms
    Paralelo:   #{Map.get(result, :parallel_ms, 0)} ms
    Mejora:     #{Map.get(result, :improvement, 0)}x
    """
  end
end
