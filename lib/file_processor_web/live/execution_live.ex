defmodule FileProcessorWeb.ExecutionLive do
  use FileProcessorWeb, :live_view

  alias FileProcessor.Executions

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    executions = Executions.list_executions()
    stats      = Executions.get_statistics()

    {:ok,
     socket
     |> assign(:executions, executions)
     |> assign(:stats, stats)
     |> assign(:filter, "all")
     |> assign(:modal, nil)}   # nil | {:delete_one, id} | :delete_all
  end

  # ---------------------------------------------------------------------------
  # Eventos — filtros
  # ---------------------------------------------------------------------------

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
          today_end   = Date.utc_today() |> DateTime.new!(~T[23:59:59])
          Executions.list_executions_filtered(date_start: today_start, date_end: today_end)

        "week" ->
          today      = Date.utc_today()
          week_start = today |> Date.beginning_of_week() |> DateTime.new!(~T[00:00:00])
          week_end   = today |> Date.end_of_week()       |> DateTime.new!(~T[23:59:59])
          Executions.list_executions_filtered(date_start: week_start, date_end: week_end)
      end

    {:noreply,
     socket
     |> assign(:executions, executions)
     |> assign(:filter, mode)}
  end

  # ---------------------------------------------------------------------------
  # Eventos — abrir/cerrar modal
  # ---------------------------------------------------------------------------

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, modal: {:delete_one, String.to_integer(id)})}
  end

  def handle_event("confirm_delete_all", _params, socket) do
    {:noreply, assign(socket, modal: :delete_all)}
  end

  def handle_event("cancel_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil)}
  end

  # ---------------------------------------------------------------------------
  # Eventos — confirmar eliminación
  # ---------------------------------------------------------------------------

  def handle_event("delete", %{"id" => id}, socket) do
    execution = Executions.get_execution!(String.to_integer(id))
    Executions.delete_execution(execution)

    {:noreply,
     socket
     |> assign(:executions, reload_executions(socket))
     |> assign(:stats, Executions.get_statistics())
     |> assign(:modal, nil)}
  end

  def handle_event("delete_all", _params, socket) do
    Executions.delete_all_executions()

    {:noreply,
     socket
     |> assign(:executions, [])
     |> assign(:stats, Executions.get_statistics())
     |> assign(:modal, nil)}
  end

  # ---------------------------------------------------------------------------
  # Privadas
  # ---------------------------------------------------------------------------

  defp reload_executions(socket) do
    case socket.assigns.filter do
      "all"   -> Executions.list_executions()
      "today" ->
        today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00])
        today_end   = Date.utc_today() |> DateTime.new!(~T[23:59:59])
        Executions.list_executions_filtered(date_start: today_start, date_end: today_end)
      "week"  ->
        today      = Date.utc_today()
        week_start = today |> Date.beginning_of_week() |> DateTime.new!(~T[00:00:00])
        week_end   = today |> Date.end_of_week()       |> DateTime.new!(~T[23:59:59])
        Executions.list_executions_filtered(date_start: week_start, date_end: week_end)
      mode    -> Executions.list_executions_filtered(mode: mode)
    end
  end
end
