# File: lib/log_parser.ex
# Purpose: Simple log file parser - COMPLETE SIMPLIFIED VERSION

defmodule LogParser do
  # Documentación del módulo
  @moduledoc """
  Log file parser for system logs.

  This module parses log files and extracts statistics about log levels.
  It counts occurrences of different log levels (DEBUG, INFO, WARN, ERROR, FATAL).

  Expected log format: YYYY-MM-DD HH:MM:SS [LEVEL] [COMPONENT] message
  Example: "2023-10-15 14:30:45 [ERROR] [Database] Connection timeout"

  ## Functions

  ### Public Functions
  - `process/1` - Main function to process log files

  ### Private Functions
  - `parse_log_line/2` - Parses individual log lines
  - `update_stats/2` - Updates counters for specific log levels
  """

  @doc """
  Main function to process log files.

  Reads a log file, parses each line, and extracts statistics about log levels.

  ## Parameters
    - `file_path`: String path to the log file

  ## Returns
    - `{:ok, metrics}` on success, where metrics is a map containing:
      - `total_lines`: Total number of lines in the file
      - `debug`: Count of DEBUG level log entries
      - `info`: Count of INFO level log entries
      - `warn`: Count of WARN level log entries
      - `error`: Count of ERROR level log entries
      - `fatal`: Count of FATAL level log entries
      - `file_name`: Base name of the processed file
    - `{:error, reason}` on failure, where reason describes the error

  ## Communication
    - Uses: `File.exists?/1`, `File.read!/1`, `String.split/3`, `Enum.reduce/3`, `Path.basename/1`
    - Calls private functions: `parse_log_line/2` (via Enum.reduce), `update_stats/2`

  ## Examples
      iex> LogParser.process("app.log")
      {:ok, %{
        total_lines: 150,
        debug: 20,
        info: 80,
        warn: 30,
        error: 15,
        fatal: 5,
        file_name: "app.log"
      }}

      iex> LogParser.process("nonexistent.log")
      {:error, "File not found: nonexistent.log"}
  """
  def process(file_path) do
    # Verifica si el archivo existe usando File.exists?/1
    if File.exists?(file_path) do
      # Bloque try para capturar errores durante el procesamiento
      try do
        # Lee archivo y divide por líneas, eliminando líneas vacías
        # File.read!/1 lee todo el contenido del archivo como string
        # String.split/3 divide el string por el separador "\n" (salto de línea)
        # trim: true elimina strings vacíos del resultado (líneas vacías)
        lines = File.read!(file_path) |> String.split("\n", trim: true)

        # Inicializa contadores para todos los niveles de log
        # Mapa con claves atómicas y valores inicializados a 0
        # Este mapa acumulará los conteos de cada nivel de log
        stats = %{debug: 0, info: 0, warn: 0, error: 0, fatal: 0}

        # Procesa cada línea acumulando estadísticas
        # Enum.reduce/3 itera sobre la lista de líneas actualizando el acumulador stats
        # Para cada línea, llama a parse_log_line/2 que actualiza los contadores
        stats =
          Enum.reduce(lines, stats, fn line, acc ->
            # Para cada línea, llama a parse_log_line/2
            # line: línea actual del archivo de log
            # acc: acumulador actual (mapa stats)
            # Retorna: nuevo acumulador actualizado
            parse_log_line(line, acc)
          end)

        # Calcula métricas finales combinando datos del procesamiento
        metrics = %{
          # Total de líneas en el archivo
          # length/1 retorna el número de elementos en la lista lines
          total_lines: length(lines),

          # Extrae cada contador del mapa stats actualizado
          # stats.debug, stats.info, etc. contienen los conteos finales
          debug: stats.debug,
          info: stats.info,
          warn: stats.warn,
          error: stats.error,
          fatal: stats.fatal,

          # Nombre del archivo: extrae solo el nombre sin la ruta completa
          # Path.basename/1 retorna el último componente de la ruta
          file_name: Path.basename(file_path)
        }

        # Retorna tupla de éxito con las métricas calculadas
        {:ok, metrics}
      rescue
        # Captura cualquier error durante el procesamiento
        # inspect/1 convierte el error a string legible para debugging
        error -> {:error, "Log parsing error: #{inspect(error)}"}
      end
    else
      # Archivo no encontrado - retorna tupla de error
      {:error, "File not found: #{file_path}"}
    end
  end

  # Parsea una línea individual de log y actualiza estadísticas
  #
  # ## Parameters
  #   - `line`: String containing a single log line
  #   - `stats`: Map with current log level counters
  #
  # ## Returns
  #   - Map: Updated stats with incremented counter if log level found
  #   - Original stats if no log level pattern found
  #
  # ## Communication
  #   - Uses: `Regex.run/2` to find log level pattern
  #   - Calls: `update_stats/2` to update counters
  #   - Called by: `process/1` via Enum.reduce
  #
  # ## Regex Pattern Explanation
  #   ~r/\[(\w+)\]/
  #   - \[ : matches literal '[' character
  #   - (\w+) : captures one or more word characters (letters, digits, underscore)
  #   - \] : matches literal ']' character
  #   Example: matches "[ERROR]" and captures "ERROR"
  defp parse_log_line(line, stats) do
    # Busca patrón de nivel de log como [ERROR], [WARN], etc.
    # Regex.run/2 busca coincidencia con expresión regular en el string
    # Retorna lista si encuentra coincidencia: [full_match, captured_group]
    # Retorna nil si no encuentra coincidencia
    case Regex.run(~r/\[(\w+)\]/, line) do
      # Si encuentra patrón: [coincidencia_completa, nivel_capturado]
      # _ (guión bajo) ignora la coincidencia completa (ej: "[ERROR]")
      # level contiene el texto capturado entre corchetes (ej: "ERROR")
      [_, level] ->
        # Actualiza contadores basado en el nivel encontrado
        # String.upcase/1 convierte a mayúsculas para estandarizar
        # Por ejemplo: "error" → "ERROR", "Error" → "ERROR"
        update_stats(stats, String.upcase(level))

      # Si no encuentra patrón, retorna stats sin cambios
      # Esto ocurre con líneas que no siguen el formato esperado
      nil ->
        stats
    end
  end

  # Actualiza contadores para cada nivel de log
  # Cada cláusula maneja un nivel específico
  #
  # ## Parameters
  #   - `stats`: Map with current log level counters
  #   - `level`: String with log level in uppercase (e.g., "ERROR", "WARN")
  #
  # ## Returns
  #   - Map: Updated stats with incremented counter for the matching level
  #
  # ## Communication
  #   - Called by: `parse_log_line/2` when a log level is found
  #   - Returns updated stats to `parse_log_line/2`
  #
  # ## Notes
  #   - Uses pattern matching to handle specific log levels
  #   - Last clause acts as catch-all for unknown levels
  #   - Uses map update syntax: %{map | key: new_value}

  # Maneja nivel DEBUG
  defp update_stats(stats, "DEBUG"), do: %{stats | debug: stats.debug + 1}

  # Maneja nivel INFO
  defp update_stats(stats, "INFO"), do: %{stats | info: stats.info + 1}

  # Maneja nivel WARN
  defp update_stats(stats, "WARN"), do: %{stats | warn: stats.warn + 1}

  # Maneja nivel ERROR
  defp update_stats(stats, "ERROR"), do: %{stats | error: stats.error + 1}

  # Maneja nivel FATAL
  defp update_stats(stats, "FATAL"), do: %{stats | fatal: stats.fatal + 1}

  # Para cualquier otro nivel (no reconocido), retorna stats sin cambios
  # _ (guión bajo) captura cualquier otro valor de level
  # Esto maneja niveles no estándar o errores en el formato
  defp update_stats(stats, _), do: stats
end
