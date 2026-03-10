defmodule FileProcessor.ExecutionHelpers do
  @moduledoc """
  Funciones de presentación y extracción de datos para ejecuciones.

  Este módulo vive en el contexto (`lib/file_processor/`) sin dependencias
  de Phoenix ni de la capa web, lo que lo hace testeable de forma aislada
  y reutilizable desde controllers, vistas y LiveViews sin duplicación.

  Consolida funciones que antes estaban duplicadas (con implementaciones
  distintas) entre `ExecutionController` y `ExecutionHTML`.

  ## Categorías

    - **Fechas**: `format_datetime/1`, `format_date/1`, `format_time/1`
    - **Íconos y badges**: `file_icon/1`, `mode_badge_color/1`, `mode_display_name/1`
    - **Archivos**: `parse_files_string/1`, `file_count/1`
    - **Reportes**: `extract_file_section/2`, `extract_metrics/2`
    - **Benchmark**: `extract_benchmark_data/1`
  """

  # ---------------------------------------------------------------------------
  # Formateo de fechas
  # ---------------------------------------------------------------------------

  @doc """
  Formatea un `DateTime` como "DD/MM/YYYY HH:MM".

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.format_datetime(~U[2026-02-15 14:30:00Z])
      "15/02/2026 14:30"
  """
  def format_datetime(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y %H:%M")

  @doc """
  Formatea un `DateTime` mostrando solo la fecha como "DD/MM/YYYY".
  """
  def format_date(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y")

  @doc """
  Formatea un `DateTime` mostrando solo la hora como "HH:MM".
  """
  def format_time(datetime), do: Calendar.strftime(datetime, "%H:%M")

  # ---------------------------------------------------------------------------
  # Íconos y badges
  # ---------------------------------------------------------------------------

  @doc """
  Devuelve el emoji correspondiente a la extensión de un archivo.

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.file_icon(".csv")
      "📊"
  """
  def file_icon(extension) do
    case extension do
      ".csv"  -> "📊"
      ".json" -> "📋"
      ".log"  -> "📝"
      _       -> "📄"
    end
  end

  @doc """
  Devuelve las clases CSS de Tailwind para el badge de un modo de procesamiento.

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.mode_badge_color("parallel")
      "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
  """
  def mode_badge_color(mode) do
    case mode do
      "sequential" -> "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"
      "parallel"   -> "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
      "benchmark"  -> "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400"
      _            -> "bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400"
    end
  end

  @doc """
  Devuelve el nombre legible con emoji para un modo de procesamiento.

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.mode_display_name("benchmark")
      "📊 Benchmark"
  """
  def mode_display_name(mode) do
    case mode do
      "sequential" -> "📋 Secuencial"
      "parallel"   -> "⚡ Paralelo"
      "benchmark"  -> "📊 Benchmark"
      _            -> mode
    end
  end

  # ---------------------------------------------------------------------------
  # Parsing de archivos
  # ---------------------------------------------------------------------------

  @doc """
  Convierte el campo `files` de una `Execution` (string separado por `", "`)
  a una lista de mapas con datos del archivo.

  ## Retorna

  Lista de mapas con:
    - `:full_name` — valor original del string
    - `:name`      — nombre base sin ruta (`Path.basename/1`)
    - `:extension` — extensión con punto (`Path.extname/1`)

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.parse_files_string("ventas.csv, usuarios.json")
      [
        %{full_name: "ventas.csv", name: "ventas.csv", extension: ".csv"},
        %{full_name: "usuarios.json", name: "usuarios.json", extension: ".json"}
      ]
  """
  def parse_files_string(files_string) do
    files_string
    |> String.split(", ", trim: true)
    |> Enum.map(fn file ->
      %{
        full_name: file,
        name:      Path.basename(file),
        extension: Path.extname(file)
      }
    end)
  end

  @doc """
  Devuelve el número de archivos registrados en una ejecución.

  Equivale a `length(parse_files_string/1)` sin construir la lista completa.

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.file_count("a.csv, b.json, c.log")
      3
  """
  def file_count(files_string) do
    files_string
    |> String.split(", ", trim: true)
    |> length()
  end

  # ---------------------------------------------------------------------------
  # Extracción de resultados del reporte
  # ---------------------------------------------------------------------------

  @doc """
  Extrae la sección de texto correspondiente a un archivo del reporte completo.

  Busca el bloque que comienza con `[nombre_archivo]` y captura todo
  hasta el siguiente bloque `[...]` o el final del texto.

  Esta función reemplaza las dos implementaciones anteriores que existían
  en `ExecutionController` (4 patrones regex) y `ExecutionHTML` (1 patrón),
  que producían resultados inconsistentes entre sí.

  ## Retorna

    - El bloque de texto del archivo, sin espacios sobrantes.
    - `"No se encontraron resultados para este archivo"` si no hay coincidencia.

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.extract_file_section(report, "ventas.csv")
      "[ventas.csv] - CSV\\n══...\\n• Registros válidos: 30"
  """
  def extract_file_section(report, file_name) do
    pattern = ~r/\[#{Regex.escape(file_name)}\].*?(?=\n\[|\z)/s

    case Regex.run(pattern, report) do
      [match] -> String.trim(match)
      nil     -> "No se encontraron resultados para este archivo"
    end
  end

  @doc """
  Extrae métricas estructuradas del bloque de texto de un archivo del reporte.

  Usa expresiones regulares para obtener valores numéricos según el tipo
  de archivo. Todos los valores son strings tal como aparecen en el reporte,
  o `""` si no se encuentran.

  ## Retorna por extensión

    - `.csv`  → `%{valid_records, unique_products, total_sales}`
    - `.json` → `%{total_users, active_users, total_sessions}`
    - `.log`  → `%{total_lines, debug, info, warn, error, fatal}`
    - otro    → `%{}`

  ## Ejemplo

      iex> FileProcessor.ExecutionHelpers.extract_metrics(block, ".csv")
      %{valid_records: "30", unique_products: "5", total_sales: "1520.75"}
  """
  def extract_metrics(file_result, extension) do
    case extension do
      ".csv" ->
        %{
          valid_records:   extract_value(file_result, ~r/Registros válidos:\s*(\d+)/),
          unique_products: extract_value(file_result, ~r/Productos únicos:\s*(\d+)/),
          total_sales:     extract_value(file_result, ~r/Ventas totales:\s*\$([\d.]+)/)
        }

      ".json" ->
        %{
          total_users:    extract_value(file_result, ~r/Total usuarios:\s*(\d+)/),
          active_users:   extract_value(file_result, ~r/Usuarios activos:\s*(\d+)/),
          total_sessions: extract_value(file_result, ~r/Total sesiones:\s*(\d+)/)
        }

      ".log" ->
        %{
          total_lines: extract_value(file_result, ~r/Total l[ií]neas:\s*(\d+)/),
          debug:       extract_value(file_result, ~r/DEBUG:\s*(\d+)/),
          info:        extract_value(file_result, ~r/INFO:\s*(\d+)/),
          warn:        extract_value(file_result, ~r/WARN:\s*(\d+)/),
          error:       extract_value(file_result, ~r/ERROR:\s*(\d+)/),
          fatal:       extract_value(file_result, ~r/FATAL:\s*(\d+)/)
        }

      _ ->
        %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Benchmark
  # ---------------------------------------------------------------------------

  @doc """
  Parsea el texto de un reporte benchmark y devuelve un mapa estructurado
  listo para usar en la vista.

  ## Retorna

  `%{sequential_ms, parallel_ms, improvement, time_saved, percent_faster, faster_mode}`
  o `nil` si no se pueden extraer los tiempos del texto.
  """
  def extract_benchmark_data(report) when is_binary(report) do
    sequential =
      extract_numeric(report, ~r/Sequential Mode:\s*([\d.]+)/i) ||
      extract_numeric(report, ~r/Secuencial:\s*([\d.]+)/i)

    parallel =
      extract_numeric(report, ~r/Parallel Mode:\s*([\d.]+)/i) ||
      extract_numeric(report, ~r/Paralelo:\s*([\d.]+)/i)

    with seq when is_number(seq) <- sequential,
         par when is_number(par) <- parallel do
      time_saved  = seq - par
      improvement = if par > 0, do: Float.round(seq / par, 2), else: 0.0
      percent     = if seq > 0, do: Float.round(abs(time_saved) / seq * 100, 1), else: 0.0

      faster_mode =
        cond do
          time_saved > 0 -> "⚡ Paralelo más rápido"
          time_saved < 0 -> "📋 Secuencial más rápido"
          true           -> "⚖️ Igual rendimiento"
        end

      %{
        sequential_ms:  seq,
        parallel_ms:    par,
        improvement:    improvement,
        time_saved:     abs(time_saved),
        percent_faster: percent,
        faster_mode:    faster_mode
      }
    else
      _ -> nil
    end
  end

  def extract_benchmark_data(_), do: nil

  # ---------------------------------------------------------------------------
  # Privadas
  # ---------------------------------------------------------------------------

  # Extrae el primer grupo capturado de un regex sobre un texto.
  # Devuelve el valor como string o "" si no hay coincidencia.
  defp extract_value(text, regex) do
    case Regex.run(regex, text) do
      [_, value] -> value
      _          -> ""
    end
  end

  # Como extract_value/2 pero convierte el resultado a número (int o float).
  # Devuelve nil si no hay coincidencia o si el valor no es parseable.
  defp extract_numeric(text, regex) do
    case Regex.run(regex, text) do
      [_, value] ->
        if String.contains?(value, ".") do
          case Float.parse(value) do
            {n, _} -> n
            :error -> nil
          end
        else
          case Integer.parse(value) do
            {n, _} -> n
            :error -> nil
          end
        end

      _ ->
        nil
    end
  end
end
