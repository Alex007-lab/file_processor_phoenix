defmodule ProcesadorArchivos.CoreAdapter do
  @moduledoc """
  Adaptador entre Phoenix y el core ProcesadorArchivos.
  Evita usar CLI directamente.
  """

  def process_sequential(file_paths) do
    Enum.map(file_paths, fn file ->
      ProcesadorArchivos.procesar_con_manejo_errores(file, %{
        timeout: 5000
      })
    end)
  end

  def process_parallel(file_paths) do
    ProcesadorArchivos.process_parallel(file_paths)
  end

  def run_benchmark(file_paths) do
    case file_paths do
      [dir] ->
        if File.dir?(dir) do
          ProcesadorArchivos.benchmark(dir, %{})
        else
          {:error, "Benchmark requiere un directorio"}
        end

      _ ->
        {:error, "Benchmark requiere un directorio"}
    end
  end
end
