defmodule ProcesadorArchivos.Coordinator do
  @moduledoc """
  Coordinador de procesos para procesamiento paralelo.

  Este módulo coordina múltiples procesos Worker para procesar archivos
  en paralelo. Gestiona la creación de workers, recolección de resultados
  y manejo de timeouts.

  ## Funciones

  ### Públicas
  - `start/2` - Inicia el procesamiento paralelo de archivos

  ### Privadas
  - `collect_results/4` - Recolecta resultados de los workers
  """

  @doc """
  Inicia el procesamiento paralelo de una lista de archivos.

  Crea un proceso Worker para cada archivo y recolecta todos los resultados.
  Los resultados se devuelven como un mapa donde las claves son las rutas
  de los archivos y los valores son los resultados del procesamiento.

  ## Parámetros
    - `files`: Lista de rutas de archivos a procesar
    - `config`: Mapa de configuración (opcional). Contiene:
        - `:timeout`: Tiempo máximo de espera por worker en milisegundos (default: 5000)
        - `:verbose`: Modo verboso para logging (default: false)

  ## Retorno
    - Mapa `%{ruta_archivo => resultado, ...}` con todos los resultados

  ## Comunicación
    - Llama a: `ProcesadorArchivos.Worker.start/3` para cada archivo
    - Llama a: `collect_results/4` para recolectar resultados
    - Recibe mensajes de workers con formato: `{:result, worker_pid, file_path, result}`

  ## Ejemplo
      iex> Coordinator.start(["./archivo1.txt", "./archivo2.txt"], %{timeout: 3000})
      %{
        "./archivo1.txt" => %{status: :ok, lines: 100},
        "./archivo2.txt" => %{status: :error, error: "File not found"}
      }
  """
  def start(files, config \\ %{}) do
    # Obtener valores de configuración con valores por defecto
    timeout = Map.get(config, :timeout, 5000)    # Timeout: 5000ms por defecto
    verbose = Map.get(config, :verbose, false)   # Modo verboso: false por defecto
    coordinator_pid = self()                     # PID del proceso coordinador actual

    # Crear un proceso Worker para cada archivo en la lista
    # Enum.each ejecuta la función para cada elemento sin retornar valor
    Enum.each(files, fn file_path ->
      # Inicia worker pasando: ruta del archivo, PID del coordinador, modo verboso
      ProcesadorArchivos.Worker.start(file_path, coordinator_pid, verbose)
    end)

    # Recolectar resultados de todos los workers creados
    # collect_results espera recibir un mensaje de cada worker
    results = collect_results(files, length(files), timeout, verbose)

    # Combinar archivos con sus resultados correspondientes
    # Enum.zip crea pares [{archivo1, resultado1}, {archivo2, resultado2}, ...]
    # Enum.into convierte la lista de pares a un mapa %{archivo => resultado}
    Enum.zip(files, results)
    |> Enum.into(%{})
  end

  # Recolecta resultados de múltiples procesos Worker.
  #
  # Espera recibir mensajes de cada worker dentro del tiempo límite especificado.
  # Si un worker no responde en el timeout, se registra un error.
  #
  # ## Parámetros
  #   - `files`: Lista original de archivos (no usada directamente, solo para contexto)
  #   - `total_count`: Número total de workers/resultados esperados
  #   - `timeout`: Tiempo máximo de espera por cada worker en milisegundos
  #   - `verbose`: Si es true, muestra mensajes de logging
  #
  # ## Retorno
  #   - Lista de resultados en el mismo orden que se esperaron
  #
  # ## Comunicación
  #   - Recibe mensajes: `{:result, worker_pid, file_path, result}`
  #   - Usa `receive` para recibir mensajes de procesos Elixir
  #
  # ## Notas
  #   - Cada iteración del Enum.map espera UN mensaje de UN worker
  #   - Si no llega mensaje en el timeout, se genera resultado de error
  defp collect_results(_files, total_count, timeout, verbose) do
    # Para cada uno de los total_count workers esperados...
    Enum.map(1..total_count, fn index ->
      # Esperar recibir un mensaje de un worker
      receive do
        # Patrón: mensaje de resultado de un worker
        # Contiene: átomo :result, PID del worker, ruta del archivo, resultado
        {:result, _worker_pid, _file_path, result} ->
          # Retornar el resultado recibido del worker
          result
      after
        # Bloque after: se ejecuta si no se recibe mensaje en el tiempo especificado
        timeout ->
          # Si está en modo verboso, mostrar mensaje de timeout
          if verbose do
            # Muestra índice actual y total, útil para debugging
            IO.puts("[#{index}/#{total_count}] Timeout after #{timeout}ms")
          end
          # Retornar estructura de error estándar
          %{status: :error, error: "Worker timeout after #{timeout}ms"}
      end
    end)
  end
end
