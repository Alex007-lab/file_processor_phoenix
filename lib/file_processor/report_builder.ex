defmodule FileProcessor.ReportBuilder do
  @moduledoc """
  Construye el texto de reporte para cada modo de procesamiento.

  Este módulo vive en el contexto (`lib/file_processor/`) sin dependencias
  de Phoenix, lo que lo hace testeable de forma aislada y reutilizable
  desde controllers y LiveViews.

  Solo se ocupa de formatear texto. La determinación del estado de la
  ejecución (`success` / `partial`) es responsabilidad del caller, usando
  directamente el campo `:status` que devuelve el core.

  ## Funciones públicas

    - `build_sequential/2`  — reporte para modo secuencial
    - `build_parallel/2`    — reporte para modo paralelo
    - `build_benchmark/2`   — reporte para modo benchmark
  """

  # ---------------------------------------------------------------------------
  # Secuencial
  # ---------------------------------------------------------------------------

  @doc """
  Construye el reporte para una ejecución en modo secuencial.

  ## Parámetros

    - `results`    — lista de mapas devueltos por `CoreAdapter.process_sequential/1`
    - `total_time` — tiempo total en milisegundos

  ## Retorna

  String con el reporte formateado.
  """
  def build_sequential(results, total_time) do
    successes = Enum.count(results, &success?/1)
    errors    = length(results) - successes

    """
    =====================================
    MODO: SECUENCIAL
    =====================================

    ⏱️  Tiempo total: #{total_time} ms
    ✅ Exitosos: #{successes}
    ❌ Errores:   #{errors}

    Resultados por archivo:
    #{format_results(results)}
    """
  end

  # ---------------------------------------------------------------------------
  # Paralelo
  # ---------------------------------------------------------------------------

  @doc """
  Construye el reporte para una ejecución en modo paralelo.

  ## Parámetros

    - `parallel_result` — mapa devuelto por `CoreAdapter.process_parallel/1`,
      que incluye `:results`, `:successes` y `:errors`
    - `total_time`      — tiempo total en milisegundos

  ## Retorna

  String con el reporte formateado.
  """
  def build_parallel(%{results: results, successes: successes, errors: errors}, total_time) do
    """
    =====================================
    MODO: PARALELO
    =====================================

    ⏱️  Tiempo total: #{total_time} ms
    ✅ Exitosos: #{successes}
    ❌ Errores:   #{errors}

    Resultados por archivo:
    #{format_results(results)}
    """
  end

  # ---------------------------------------------------------------------------
  # Benchmark
  # ---------------------------------------------------------------------------

  @doc """
  Construye el reporte para una ejecución en modo benchmark.

  ## Parámetros

    - `benchmark_data` — mapa devuelto por `CoreAdapter.run_benchmark/1`
    - `total_time`     — tiempo total en milisegundos

  ## Retorna

  String con el reporte formateado.
  """
  def build_benchmark(benchmark_data, total_time) do
    seq     = Map.get(benchmark_data, :sequential_ms, 0)
    par     = Map.get(benchmark_data, :parallel_ms, 0)
    imp     = Map.get(benchmark_data, :improvement, 0)
    percent = Map.get(benchmark_data, :percent_faster, 0)

    faster =
      cond do
        seq > par -> "⚡ Paralelo es más rápido"
        seq < par -> "📋 Secuencial es más rápido"
        true      -> "⚖️ Mismo rendimiento"
      end

    """
    📊 BENCHMARK RESULTS
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📈 Secuencial: #{seq} ms
    ⚡ Paralelo:    #{par} ms
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #{faster}
    🚀 Factor de mejora: #{imp}x
    ⏱️  Diferencia: #{abs(seq - par)} ms
    📊 Eficiencia: #{abs(percent)}% #{if percent > 0, do: "más rápido", else: "más lento"}

    ⏱️  Tiempo total de benchmark: #{total_time} ms

    Reporte completo:
    #{Map.get(benchmark_data, :full_report, "No disponible")}
    """
  end

  # ---------------------------------------------------------------------------
  # Privadas
  # ---------------------------------------------------------------------------

  defp format_results(results) do
    results
    |> Enum.map(&format_file_result/1)
    |> Enum.join("\n\n")
  end

  # Determina si un resultado del core es exitoso.
  # Maneja los dos formatos que puede devolver el core:
  #   - Formato parser directo: %{status: :success}
  #   - Formato error handler:  %{estado: :completo}
  defp success?(%{status: :success}), do: true
  defp success?(%{estado: :completo}), do: true
  defp success?(_), do: false

  # Formato parser directo — CSV exitoso
  defp format_file_result(%{type: :csv, status: :success, file_name: file} = r) do
    """
    [#{file}] - CSV
    ═══════════════════════════════
    • Estado: éxito
    • Registros válidos: #{r.valid_records}
    • Productos únicos: #{r.unique_products}
    • Ventas totales: $#{:erlang.float_to_binary(r.total_sales, decimals: 2)}
    """
  end

  # Formato parser directo — JSON exitoso
  defp format_file_result(%{type: :json, status: :success, file_name: file} = r) do
    """
    [#{file}] - JSON
    ═══════════════════════════════
    • Estado: éxito
    • Total usuarios: #{r.total_users}
    • Usuarios activos: #{r.active_users}
    • Total sesiones: #{r.total_sessions}
    """
  end

  # Formato parser directo — LOG exitoso
  defp format_file_result(%{type: :log, status: :success, file_name: file} = r) do
    """
    [#{file}] - LOG
    ═══════════════════════════════
    • Estado: éxito
    • Total líneas: #{r.total_lines}
    • Distribución:
        DEBUG: #{r.debug}
        INFO:  #{r.info}
        WARN:  #{r.warn}
        ERROR: #{r.error}
        FATAL: #{r.fatal}
    """
  end

  # Formato error handler — CSV
  defp format_file_result(%{tipo_archivo: :csv, archivo: file} = r) do
    detalles = Map.get(r, :detalles, %{})
    estado   = if success?(r), do: "éxito", else: "error"

    """
    [#{file}] - CSV
    ═══════════════════════════════
    • Estado: #{estado}
    • Registros válidos: #{Map.get(detalles, :lineas_validas, 0)}
    • Registros inválidos: #{Map.get(detalles, :lineas_invalidas, 0)}
    • Total líneas: #{Map.get(detalles, :total_lineas, 0)}
    • Éxito: #{Map.get(detalles, :porcentaje_exito, 0)}%
    """
  end

  # Formato error handler — JSON
  defp format_file_result(%{tipo_archivo: :json, archivo: file} = r) do
    detalles = Map.get(r, :detalles, %{})
    estado   = if success?(r), do: "éxito", else: "error"

    """
    [#{file}] - JSON
    ═══════════════════════════════
    • Estado: #{estado}
    • Total usuarios: #{Map.get(detalles, :total_usuarios, 0)}
    • Usuarios activos: #{Map.get(detalles, :usuarios_activos, 0)}
    • Total sesiones: #{Map.get(detalles, :total_sesiones, 0)}
    """
  end

  # Formato error handler — LOG
  defp format_file_result(%{tipo_archivo: :log, archivo: file} = r) do
    detalles = Map.get(r, :detalles, %{})
    niveles  = Map.get(detalles, :distribucion_niveles, %{})
    estado   = if success?(r), do: "éxito", else: "error"

    """
    [#{file}] - LOG
    ═══════════════════════════════
    • Estado: #{estado}
    • Líneas válidas: #{Map.get(r, :lineas_procesadas, 0)}
    • Líneas inválidas: #{Map.get(r, :lineas_con_error, 0)}
    • Total líneas: #{Map.get(detalles, :total_lineas, 0)}
    • Distribución:
        DEBUG: #{Map.get(niveles, :debug, 0)}
        INFO:  #{Map.get(niveles, :info, 0)}
        WARN:  #{Map.get(niveles, :warn, 0)}
        ERROR: #{Map.get(niveles, :error, 0)}
        FATAL: #{Map.get(niveles, :fatal, 0)}
    """
  end

  # Error genérico del core
  defp format_file_result(%{status: :error, file_name: file} = r) do
    """
    [#{file}] - ERROR
    ═══════════════════════════════
    • Estado: error
    • Razón: #{Map.get(r, :error, "desconocido")}
    """
  end

  # Fallback para estructuras inesperadas
  defp format_file_result(other) do
    inspect(other, pretty: true)
  end
end
