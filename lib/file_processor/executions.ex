defmodule FileProcessor.Executions do
  @moduledoc """
  Contexto para el manejo de ejecuciones.
  """

  import Ecto.Query, warn: false
  alias FileProcessor.Repo
  alias FileProcessor.Executions.Execution

  # ---------------------------------------------------------------------------
  # Queries de lectura
  # ---------------------------------------------------------------------------

  @doc """
  Devuelve todas las ejecuciones ordenadas por fecha descendente.
  """
  def list_executions do
    Repo.all(from e in Execution, order_by: [desc: e.timestamp])
  end

  @doc """
  Devuelve ejecuciones aplicando filtros opcionales.

  Punto de entrada único para listar ejecuciones con cualquier combinación
  de filtros. Reemplaza `list_executions_by_mode/1` y
  `list_executions_by_date_range/2` que antes eran funciones separadas.

  ## Filtros soportados

    - `:mode`       — string: `"sequential"`, `"parallel"`, `"benchmark"`
    - `:date_start` — `DateTime` inicio del rango
    - `:date_end`   — `DateTime` fin del rango

  ## Ejemplos

      list_executions_filtered(mode: "parallel")
      list_executions_filtered(date_start: ~U[2026-02-01 00:00:00Z], date_end: ~U[2026-02-28 23:59:59Z])
      list_executions_filtered(mode: "benchmark", date_start: start, date_end: end)
  """
  def list_executions_filtered(filters \\ []) do
    Execution
    |> apply_filters(filters)
    |> order_by([e], desc: e.timestamp)
    |> Repo.all()
  end

  @doc """
  Devuelve ejecuciones paginadas con los filtros aplicados.

  ## Parámetros

    - `filters` — mismos filtros que `list_executions_filtered/1`
    - `page`     — página actual (base 1)
    - `per_page` — registros por página

  ## Retorna

      %{
        entries:    [%Execution{}],
        page:       integer,
        per_page:   integer,
        total:      integer,
        total_pages: integer
      }
  """
  def list_executions_paginated(filters \\ [], page \\ 1, per_page \\ 10) do
    base_query =
      Execution
      |> apply_filters(filters)
      |> order_by([e], desc: e.timestamp)

    total   = Repo.aggregate(base_query, :count, :id)
    entries = base_query |> limit(^per_page) |> offset(^((page - 1) * per_page)) |> Repo.all()

    %{
      entries:     entries,
      page:        page,
      per_page:    per_page,
      total:       total,
      total_pages: max(1, ceil(total / per_page))
    }
  end

  @doc """
  Obtiene una ejecución por id.
  Lanza `Ecto.NoResultsError` si no existe.
  """
  def get_execution!(id), do: Repo.get!(Execution, id)

  @doc """
  Devuelve estadísticas globales de ejecuciones en una sola query.

  Reemplaza las 4 queries separadas de la versión anterior
  (3 `Repo.aggregate` por modo + 1 para el promedio).

  ## Retorna

      %{
        total:       integer,
        sequential:  integer,
        parallel:    integer,
        benchmark:   integer,
        avg_time:    integer  # en milisegundos, 0 si no hay registros
      }
  """
  def get_statistics do
    rows =
      Repo.all(
        from e in Execution,
          group_by: e.mode,
          select: {e.mode, count(e.id), avg(e.total_time)}
      )

    # Construir mapa base con ceros
    base = %{total: 0, sequential: 0, parallel: 0, benchmark: 0, avg_time: 0}

    {stats, total_weighted, total_count} =
      Enum.reduce(rows, {base, 0.0, 0}, fn {mode, count, avg_time}, {acc, weighted, n} ->
        avg_ms   = decimal_to_integer(avg_time)
        mode_key = mode_to_key(mode)

        updated = Map.put(acc, mode_key, count)
        {updated, weighted + avg_ms * count, n + count}
      end)

    global_avg =
      if total_count > 0,
        do: round(total_weighted / total_count),
        else: 0

    %{stats | total: total_count, avg_time: global_avg}
  end

  # ---------------------------------------------------------------------------
  # Mutaciones
  # ---------------------------------------------------------------------------

  @doc """
  Crea una ejecución.
  """
  def create_execution(attrs) do
    %Execution{}
    |> Execution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Actualiza una ejecución.
  """
  def update_execution(%Execution{} = execution, attrs) do
    execution
    |> Execution.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Elimina una ejecución.
  """
  def delete_execution(%Execution{} = execution) do
    Repo.delete(execution)
  end

  @doc """
  Elimina todas las ejecuciones.
  """
  def delete_all_executions do
    Repo.delete_all(Execution)
  end

  @doc """
  Devuelve un changeset para tracking de cambios.
  """
  def change_execution(%Execution{} = execution, attrs \\ %{}) do
    Execution.changeset(execution, attrs)
  end

  # ---------------------------------------------------------------------------
  # Privadas
  # ---------------------------------------------------------------------------

  # Aplica cada filtro de la lista a la query de forma encadenada.
  defp apply_filters(query, []), do: query

  defp apply_filters(query, [{:mode, mode} | rest]) when mode in ["sequential", "parallel", "benchmark"] do
    query
    |> where([e], e.mode == ^mode)
    |> apply_filters(rest)
  end

  defp apply_filters(query, [{:date_start, date_start} | rest]) do
    query
    |> where([e], e.timestamp >= ^date_start)
    |> apply_filters(rest)
  end

  defp apply_filters(query, [{:date_end, date_end} | rest]) do
    query
    |> where([e], e.timestamp <= ^date_end)
    |> apply_filters(rest)
  end

  # Ignora filtros desconocidos en lugar de crashear.
  defp apply_filters(query, [_unknown | rest]), do: apply_filters(query, rest)

  # Convierte el resultado de avg() (que Ecto devuelve como Decimal, float o nil)
  # a integer de forma segura.
  defp decimal_to_integer(nil), do: 0
  defp decimal_to_integer(%Decimal{} = d), do: d |> Decimal.round(0) |> Decimal.to_integer()
  defp decimal_to_integer(f) when is_float(f), do: round(f)
  defp decimal_to_integer(i) when is_integer(i), do: i

  # Convierte el string de modo de la BD a clave de átomo para el mapa de stats.
  defp mode_to_key("sequential"), do: :sequential
  defp mode_to_key("parallel"),   do: :parallel
  defp mode_to_key("benchmark"),  do: :benchmark
  defp mode_to_key(_),            do: :unknown
end
