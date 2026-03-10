defmodule ProcesadorArchivos.CoreAdapter do
  @moduledoc """
  Adaptador entre Phoenix y el core ProcesadorArchivos.

  Centraliza las llamadas al core para que los controllers no dependan
  directamente de los módulos internos de ProcesadorArchivos.

  El core genera reportes en `output/` automáticamente como parte de su flujo.
  Dado que Phoenix guarda el contenido del reporte en la base de datos,
  los archivos en disco son redundantes. Este módulo los elimina tras cada
  llamada para que `output/` permanezca vacío entre ejecuciones.

  Los reportes descargables se generan desde el contenido de la BD,
  no desde archivos en disco.
  """

  @output_dir "output"

  # ---------------------------------------------------------------------------
  # Procesamiento
  # ---------------------------------------------------------------------------

  @doc """
  Procesa una lista de archivos de forma secuencial usando los parsers directos
  del core (`ProcesadorArchivos.process_file/1`).

  Devuelve una lista de mapas con el formato estándar del parser:
  `%{type, status, file_name, ...métricas específicas por tipo}`.
  """
  def process_sequential(file_paths) do
    results = Enum.map(file_paths, &ProcesadorArchivos.process_file/1)
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
  # Privadas — limpieza
  # ---------------------------------------------------------------------------

  # Elimina todos los archivos dentro de output/ sin eliminar el directorio.
  # El core necesita que el directorio exista, así que solo vaciamos su contenido.
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
