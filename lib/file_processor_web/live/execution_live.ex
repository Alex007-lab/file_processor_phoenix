defmodule FileProcessorWeb.ExecutionLive do
  use FileProcessorWeb, :live_view

  alias FileProcessor.Executions

  @per_page 10

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    stats  = Executions.get_statistics()
    paged  = Executions.list_executions_paginated([], 1, @per_page)

    {:ok,
     socket
     |> assign(:stats,       stats)
     |> assign(:filter,      "all")
     |> assign(:modal,       nil)
     |> assign_pagination(paged)}
  end

  # ---------------------------------------------------------------------------
  # Eventos — filtros
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("filter", %{"mode" => mode}, socket) do
    filters = build_filters(mode)
    paged   = Executions.list_executions_paginated(filters, 1, @per_page)

    {:noreply,
     socket
     |> assign(:filter, mode)
     |> assign_pagination(paged)}
  end

  # ---------------------------------------------------------------------------
  # Eventos — paginación
  # ---------------------------------------------------------------------------

  def handle_event("prev_page", _params, socket) do
    go_to_page(socket, socket.assigns.page - 1)
  end

  def handle_event("next_page", _params, socket) do
    go_to_page(socket, socket.assigns.page + 1)
  end

  def handle_event("go_to_page", %{"page" => page}, socket) do
    go_to_page(socket, String.to_integer(page))
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

    filters = build_filters(socket.assigns.filter)

    # Si al borrar la página actual queda vacía, retroceder una página
    new_page =
      if socket.assigns.page > 1 and length(socket.assigns.executions) == 1 do
        socket.assigns.page - 1
      else
        socket.assigns.page
      end

    paged = Executions.list_executions_paginated(filters, new_page, @per_page)

    {:noreply,
     socket
     |> assign(:stats, Executions.get_statistics())
     |> assign(:modal, nil)
     |> assign_pagination(paged)}
  end

  def handle_event("delete_all", _params, socket) do
    Executions.delete_all_executions()

    paged = Executions.list_executions_paginated([], 1, @per_page)

    {:noreply,
     socket
     |> assign(:stats,  Executions.get_statistics())
     |> assign(:filter, "all")
     |> assign(:modal,  nil)
     |> assign_pagination(paged)}
  end

  # ---------------------------------------------------------------------------
  # Privadas
  # ---------------------------------------------------------------------------

  defp go_to_page(socket, page) do
    page    = max(1, min(page, socket.assigns.total_pages))
    filters = build_filters(socket.assigns.filter)
    paged   = Executions.list_executions_paginated(filters, page, @per_page)

    {:noreply, assign_pagination(socket, paged)}
  end

  defp assign_pagination(socket, paged) do
    socket
    |> assign(:executions,  paged.entries)
    |> assign(:page,        paged.page)
    |> assign(:total_pages, paged.total_pages)
    |> assign(:total_count, paged.total)
  end

  defp build_filters("all"),        do: []
  defp build_filters("sequential"), do: [mode: "sequential"]
  defp build_filters("parallel"),   do: [mode: "parallel"]
  defp build_filters("benchmark"),  do: [mode: "benchmark"]
  defp build_filters("today") do
    [
      date_start: Date.utc_today() |> DateTime.new!(~T[00:00:00]),
      date_end:   Date.utc_today() |> DateTime.new!(~T[23:59:59])
    ]
  end
  defp build_filters("week") do
    today = Date.utc_today()
    [
      date_start: today |> Date.beginning_of_week() |> DateTime.new!(~T[00:00:00]),
      date_end:   today |> Date.end_of_week()       |> DateTime.new!(~T[23:59:59])
    ]
  end
  defp build_filters(_), do: []
end
