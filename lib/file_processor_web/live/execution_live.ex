defmodule FileProcessorWeb.ExecutionLive do
  use FileProcessorWeb, :live_view

  alias FileProcessor.Executions

  # -----------------------------------------------------------
  # Mount
  # -----------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    executions = Executions.list_executions()
    stats = Executions.get_statistics()

    {:ok,
     socket
     |> assign(:executions, executions)
     |> assign(:stats, stats)
     |> assign(:filter, "all")}
  end

  # -----------------------------------------------------------
  # Eventos
  # -----------------------------------------------------------

  @impl true
  def handle_event("filter", %{"mode" => mode}, socket) do
    executions =
      case mode do
        "all" ->
          Executions.list_executions()

        "sequential" ->
          Executions.list_executions_filtered(mode: "sequential")

        "parallel" ->
          Executions.list_executions_filtered(mode: "parallel")

        "benchmark" ->
          Executions.list_executions_filtered(mode: "benchmark")

        "today" ->
          today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00])
          today_end = Date.utc_today() |> DateTime.new!(~T[23:59:59])

          Executions.list_executions_filtered(
            date_start: today_start,
            date_end: today_end
          )

        "week" ->
          today = Date.utc_today()

          week_start =
            Date.beginning_of_week(today)
            |> DateTime.new!(~T[00:00:00])

          week_end =
            Date.end_of_week(today)
            |> DateTime.new!(~T[23:59:59])

          Executions.list_executions_filtered(
            date_start: week_start,
            date_end: week_end
          )
      end

    {:noreply,
     socket
     |> assign(:executions, executions)
     |> assign(:filter, mode)}
  end
end
