defmodule FileProcessorWeb.ExecutionController do
  use FileProcessorWeb, :controller

  alias FileProcessor.Executions
  alias FileProcessor.ExecutionHelpers

  # ---------------------------------------------------------------------------
  # Acciones
  # ---------------------------------------------------------------------------

  def index(conn, params) do
    executions = get_filtered_executions(params)
    stats = Executions.get_statistics()

    render(conn, :index,
      executions: executions,
      stats: stats,
      current_filter: params["mode"] || "all"
    )
  end

  def show(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)

    benchmark_data =
      if execution.mode == "benchmark" do
        ExecutionHelpers.extract_benchmark_data(execution.result)
      else
        nil
      end

    render(conn, :show_with_styles,
      execution: execution,
      benchmark_data: benchmark_data
    )
  end

  def download(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)

    send_download(conn, {:binary, execution.result},
      filename: "execution_#{execution.id}.txt",
      content_type: "text/plain"
    )
  end

  def delete(conn, %{"id" => id}) do
    execution = Executions.get_execution!(id)
    {:ok, _execution} = Executions.delete_execution(execution)

    conn
    |> put_flash(:info, "Ejecución eliminada exitosamente")
    |> redirect(to: ~p"/executions")
  end

  def delete_all(conn, _params) do
    Executions.delete_all_executions()

    conn
    |> put_flash(:info, "Todo el historial ha sido eliminado")
    |> redirect(to: ~p"/executions")
  end

  # ---------------------------------------------------------------------------
  # Privadas — filtrado
  # ---------------------------------------------------------------------------

  defp get_filtered_executions(params) do
    case params["mode"] do
      mode when mode in ["sequential", "parallel", "benchmark"] ->
        Executions.list_executions_filtered(mode: mode)

      "today" ->
        today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00])
        today_end   = Date.utc_today() |> DateTime.new!(~T[23:59:59])
        Executions.list_executions_filtered(date_start: today_start, date_end: today_end)

      "week" ->
        today      = Date.utc_today()
        week_start = DateTime.new!(Date.beginning_of_week(today), ~T[00:00:00])
        week_end   = DateTime.new!(Date.end_of_week(today), ~T[23:59:59])
        Executions.list_executions_filtered(date_start: week_start, date_end: week_end)

      _ ->
        Executions.list_executions()
    end
  end
end
