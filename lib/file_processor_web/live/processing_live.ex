defmodule FileProcessorWeb.ProcessingLive do
  use FileProcessorWeb, :live_view

  alias FileProcessor.Executions
  alias FileProcessor.ReportBuilder
  alias ProcesadorArchivos.CoreAdapter

  @allowed_extensions ~w(.csv .json .log)
  @max_file_size_mb 10

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        mode:             "sequential",
        phase:            :idle,
        file_states:      [],
        filenames:        [],
        results:          [],
        error:            nil,
        saved_execution:  nil,
        start_time:       0
      )
      |> allow_upload(:files,
        accept:      @allowed_extensions,
        max_entries: 10,
        max_file_size: @max_file_size_mb * 1_000_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Eventos
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mode: mode)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event("process", _params, socket) do
    entries = socket.assigns.uploads.files.entries

    cond do
      entries == [] ->
        {:noreply, assign(socket, error: "Selecciona al menos un archivo")}

      Enum.any?(entries, & &1.valid? == false) ->
        {:noreply, assign(socket, error: "Hay archivos con errores. Revísalos antes de continuar.")}

      true ->
        start_processing(socket)
    end
  end

  def handle_event("reset", _params, socket) do
    socket =
      socket
      |> assign(
        phase:            :idle,
        file_states:      [],
        filenames:        [],
        results:          [],
        error:            nil,
        saved_execution:  nil,
        start_time:       0
      )
      |> allow_upload(:files,
        accept:      @allowed_extensions,
        max_entries: 10,
        max_file_size: @max_file_size_mb * 1_000_000
      )

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Mensajes internos — feedback en tiempo real
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:file_processing, filename}, socket) do
    file_states = socket.assigns.file_states |> Enum.map(fn
      {^filename, _} -> {filename, :processing}
      other          -> other
    end)
    {:noreply, assign(socket, file_states: file_states)}
  end

  def handle_info({:file_done, filename, result}, socket) do
    status      = cond do
      result_success?(result)  -> :success
      result_partial?(result)  -> :partial
      true                     -> :error
    end
    file_states = socket.assigns.file_states |> Enum.map(fn
      {^filename, _} -> {filename, status}
      other          -> other
    end)
    results = socket.assigns.results ++ [{filename, result}]

    socket = assign(socket, file_states: file_states, results: results)

    # Si todos los archivos terminaron, guardar en BD
    total    = length(socket.assigns.file_states)
    finished = Enum.count(socket.assigns.file_states, fn {_, s} -> s in [:success, :partial, :error] end)

    socket =
      if finished == total do
        finalize_execution(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:benchmark_done, result}, socket) do
    socket =
      case result do
        {:ok, data} ->
          finalize_benchmark(socket, data)

        {:error, reason} ->
          assign(socket, phase: :error, error: "Error en benchmark: #{reason}")
      end

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">

      <.header>
        Procesar Archivos
        <:subtitle>Sube archivos CSV, JSON o LOG para analizar su contenido</:subtitle>
        <:actions>
          <.link navigate={~p"/executions"}>
            <button type="button" class="inline-flex items-center gap-2 px-4 py-2 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
              <.icon name="hero-clock" class="w-4 h-4" /> Historial
            </button>
          </.link>
        </:actions>
      </.header>

      <%= if @error do %>
        <div class="rounded-lg bg-red-50 border border-red-200 p-4 mb-6 flex items-center gap-3">
          <.icon name="hero-exclamation-circle" class="w-5 h-5 text-red-500 shrink-0" />
          <span class="text-red-700 text-sm">{@error}</span>
        </div>
      <% end %>

      <!-- Formulario — visible solo en fase idle -->
      <%= if @phase == :idle do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-6 mb-6">
          <form phx-change="validate" phx-submit="process">

          <!-- Selector de modo -->
          <div class="mb-6">
            <p class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
              Modo de procesamiento
            </p>
            <div class="grid grid-cols-3 gap-3">
              <%= for {emoji, label, value, desc} <- [
                {"📋", "Secuencial", "sequential", "Uno por uno"},
                {"⚡", "Paralelo",   "parallel",   "Simultáneo"},
                {"📊", "Benchmark",  "benchmark",  "Comparativa"}
              ] do %>
                <% active = @mode == value %>
                <button
                  type="button"
                  phx-click="set_mode"
                  phx-value-mode={value}
                  aria-pressed={to_string(active)}
                  class={[
                    "p-3 rounded-lg border-2 text-left transition-all relative",
                    if(active,
                      do:   "border-blue-500 bg-blue-50 dark:bg-blue-900/20",
                      else: "border-gray-200 dark:border-gray-600 hover:border-gray-300"
                    )
                  ]}
                >
                  <%= if active do %>
                    <span class="absolute top-2 right-2 text-blue-500">
                      <.icon name="hero-check-circle" class="w-4 h-4" />
                    </span>
                  <% end %>
                  <div class="font-medium text-sm text-gray-900 dark:text-white">{emoji} {label}</div>
                  <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">{desc}</div>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Zona de upload drag & drop -->
          <div class="mb-6">
            <p class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
              Archivos
            </p>

            <div
              id="drop-zone"
              phx-hook="DropZone"
              phx-drop-target={@uploads.files.ref}
              class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg p-8 text-center transition-colors cursor-pointer"
            >
              <.live_file_input upload={@uploads.files} class="absolute opacity-0 w-0 h-0" />
              <%= if @uploads.files.entries == [] do %>
                <.icon name="hero-cloud-arrow-up" class="w-10 h-10 text-gray-400 mx-auto mb-3" />
                <p class="text-gray-600 dark:text-gray-400 mb-1">Arrastra archivos aquí</p>
                <p class="text-sm text-gray-500 dark:text-gray-400 mb-3">o</p>
                <button
                  type="button"
                  onclick="document.querySelector('input[type=file]').click()"
                  class="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
                >
                  Seleccionar archivos
                </button>
                <p class="text-xs text-gray-400 dark:text-gray-500 mt-3">
                  CSV, JSON, LOG · Máximo 10 archivos · 10 MB por archivo
                </p>
              <% else %>
                <.icon name="hero-document-check" class="w-8 h-8 text-blue-400 mx-auto mb-2" />
                <p class="text-sm text-blue-600 dark:text-blue-400 font-medium">
                  {length(@uploads.files.entries)} archivo(s) seleccionado(s)
                </p>
                <button
                  type="button"
                  onclick="document.querySelector('input[type=file]').click()"
                  class="mt-2 text-xs text-gray-500 hover:text-blue-600 transition-colors underline"
                >
                  Agregar más archivos
                </button>
              <% end %>
            </div>

            <!-- Lista de archivos seleccionados -->
            <%= if @uploads.files.entries != [] do %>
              <div class="mt-4 space-y-2">
                <%= for entry <- @uploads.files.entries do %>
                  <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg">
                    <div class="flex items-center gap-3">
                      <span class="text-xl">{file_icon(Path.extname(entry.client_name))}</span>
                      <div>
                        <p class="text-sm font-medium text-gray-900 dark:text-white">
                          {entry.client_name}
                        </p>
                        <p class="text-xs text-gray-500">{format_size(entry.client_size)}</p>
                      </div>
                    </div>

                    <div class="flex items-center gap-3">
                      <%= if upload_errors(@uploads.files, entry) != [] do %>
                        <%= for err <- upload_errors(@uploads.files, entry) do %>
                          <span class="text-xs text-red-500">{upload_error_message(err)}</span>
                        <% end %>
                      <% else %>
                        <%= if entry.progress < 100 do %>
                          <div class="w-24">
                            <div class="flex justify-between text-xs text-gray-400 mb-0.5">
                              <span>Subiendo...</span>
                              <span>{entry.progress}%</span>
                            </div>
                            <div class="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                              <div
                                class="h-full bg-blue-500 transition-all duration-300"
                                style={"width: #{entry.progress}%"}
                              ></div>
                            </div>
                          </div>
                        <% else %>
                          <span class="text-xs text-green-500 flex items-center gap-1">
                            <.icon name="hero-check-circle" class="w-4 h-4" /> Listo
                          </span>
                        <% end %>
                      <% end %>

                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        class="text-gray-400 hover:text-red-500 transition-colors"
                        title="Quitar archivo"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Botón procesar -->
          <%= if @uploads.files.entries != [] do %>
            <button
              type="submit"
              class="w-full py-2.5 px-4 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
            >
              <.icon name="hero-play" class="w-4 h-4" /> Procesar archivos
            </button>
          <% else %>
            <button
              type="button"
              disabled
              class="w-full py-2.5 px-4 bg-gray-200 text-gray-400 font-medium rounded-lg cursor-not-allowed flex items-center justify-center gap-2"
            >
              <.icon name="hero-play" class="w-4 h-4" /> Procesar archivos
            </button>
          <% end %>

          </form>
        </div>
      <% end %>

      <!-- Fase: procesando / completado -->
      <%= if @phase in [:processing, :done] do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-6 mb-6">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
            <%= if @phase == :processing do %>
              <svg class="animate-spin w-5 h-5 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
              </svg>
              Procesando archivos...
            <% else %>
              <.icon name="hero-check-circle" class="w-5 h-5 text-green-500" />
              Procesamiento completado
            <% end %>
          </h2>

          <div class="space-y-3">
            <%= for {filename, status} <- @file_states do %>
              <div class="flex items-center gap-3 p-3 rounded-lg bg-gray-50 dark:bg-gray-700/50">
                <span class="text-xl">{file_icon(Path.extname(filename))}</span>
                <span class="flex-1 text-sm font-mono text-gray-900 dark:text-white">{filename}</span>
                <span class={
                  case status do
                    :processing -> "text-sm font-medium text-blue-500"
                    :success    -> "text-sm font-medium text-green-500"
                    :partial    -> "text-sm font-medium text-yellow-500"
                    :error      -> "text-sm font-medium text-red-500"
                    :pending    -> "text-sm font-medium text-gray-400"
                  end
                }>
                  {case status do
                    :processing -> "⏳ procesando..."
                    :success    -> "✅ completado"
                    :partial    -> "⚠️ parcial"
                    :error      -> "❌ error"
                    :pending    -> "· en cola"
                  end}
                </span>
              </div>
            <% end %>
          </div>

          <%= if @mode == "benchmark" and @phase == :processing do %>
            <p class="mt-4 text-center text-sm text-gray-500">
              El benchmark ejecuta dos corridas completas. Esto puede tardar unos segundos...
            </p>
          <% end %>

          <%= if @phase == :done and @saved_execution do %>
            <div class="mt-6 border-t border-gray-200 dark:border-gray-600 pt-6 flex gap-3">
              <.link
                navigate={~p"/executions/#{@saved_execution.id}"}
                class="flex-1 py-2.5 px-4 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
              >
                <.icon name="hero-document-text" class="w-4 h-4" /> Ver reporte completo
              </.link>
              <button
                type="button"
                phx-click="reset"
                class="py-2.5 px-4 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 border border-gray-300 dark:border-gray-600 font-medium rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors flex items-center gap-2"
              >
                <.icon name="hero-plus" class="w-4 h-4" /> Nueva ejecución
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Privadas — procesamiento
  # ---------------------------------------------------------------------------

  defp start_processing(socket) do
    mode       = socket.assigns.mode
    lv_pid     = self()
    start_time = System.monotonic_time(:millisecond)

    # Guardar archivos en disco y obtener rutas + nombres
    {saved_paths, filenames} =
      consume_uploaded_entries(socket, :files, fn %{path: tmp_path}, entry ->
        dest_dir  = Path.join(:code.priv_dir(:file_processor), "uploads")
        File.mkdir_p!(dest_dir)
        dest = Path.join(dest_dir, entry.client_name)
        File.cp!(tmp_path, dest)
        {:ok, {dest, entry.client_name}}
      end)
      |> Enum.unzip()

    # Inicializar estado de cada archivo manteniendo el orden de subida
    file_states =
      if mode == "benchmark" do
        [{"benchmark", :processing}]
      else
        filenames |> Enum.map(fn name -> {name, :pending} end)
      end

    socket = assign(socket,
      phase:       :processing,
      file_states: file_states,
      filenames:   filenames,
      start_time:  start_time,
      error:       nil
    )

    # Lanzar procesamiento en background
    case mode do
      "benchmark" ->
        Task.start(fn ->
          result = CoreAdapter.run_benchmark(saved_paths)
          send(lv_pid, {:benchmark_done, result})
        end)

      _ ->
        Enum.each(Enum.zip(filenames, saved_paths), fn {filename, path} ->
          Task.start(fn ->
            send(lv_pid, {:file_processing, filename})
            result = CoreAdapter.process_file_single(path)
            send(lv_pid, {:file_done, filename, result})
          end)
        end)
    end

    {:noreply, socket}
  end

  defp finalize_execution(socket) do
    results    = socket.assigns.results
    mode       = socket.assigns.mode
    filenames  = socket.assigns.file_states |> Enum.map(fn {name, _} -> name end)
    total_time = System.monotonic_time(:millisecond) - socket.assigns.start_time

    raw_results = Enum.map(results, fn {_name, result} -> result end)
    status =
      cond do
        Enum.all?(raw_results, &result_success?/1)                          -> "success"
        Enum.all?(raw_results, &(not result_success?(&1)))                  -> "error"
        true                                                                 -> "partial"
      end

    report =
      case mode do
        "parallel" -> ReportBuilder.build_parallel(%{results: raw_results, successes: Enum.count(raw_results, &result_success?/1), errors: Enum.count(raw_results, &(not result_success?(&1)))}, total_time)
        _          -> ReportBuilder.build_sequential(raw_results, total_time)
      end

    attrs = %{
      timestamp:   DateTime.utc_now(),
      files:       Enum.join(filenames, ", "),
      mode:        mode,
      total_time:  total_time,
      result:      report,
      status:      status,
      report_path: nil
    }

    case Executions.create_execution(attrs) do
      {:ok, execution} ->
        assign(socket, phase: :done, saved_execution: execution)

      {:error, _} ->
        assign(socket, phase: :done, error: "No se pudo guardar la ejecución")
    end
  end

  defp finalize_benchmark(socket, data) do
    total_time = System.monotonic_time(:millisecond) - socket.assigns.start_time
    report     = ReportBuilder.build_benchmark(data, total_time)
    filenames  = socket.assigns.filenames

    attrs = %{
      timestamp:   DateTime.utc_now(),
      files:       Enum.join(filenames, ", "),
      mode:        "benchmark",
      total_time:  total_time,
      result:      report,
      status:      "success",
      report_path: nil
    }

    file_states = %{"benchmark" => :success}
    socket = assign(socket, file_states: file_states)

    case Executions.create_execution(attrs) do
      {:ok, execution} ->
        assign(socket, phase: :done, saved_execution: execution)

      {:error, _} ->
        assign(socket, phase: :done, error: "No se pudo guardar la ejecución")
    end
  end

  # ---------------------------------------------------------------------------
  # Privadas — helpers de template
  # ---------------------------------------------------------------------------

  # Maneja los dos formatos que devuelve el core:
  # - Formato directo:       %{status: :success}
  # - Formato error handler: %{estado: :completo}
  defp result_success?(%{status: :success}), do: true
  defp result_success?(%{estado: :completo}), do: true
  defp result_success?(_), do: false

  defp result_partial?(%{status: :partial}), do: true
  defp result_partial?(_), do: false

  defp file_icon(".csv"), do: "📊"
  defp file_icon(".json"), do: "📋"
  defp file_icon(".log"), do: "📄"
  defp file_icon(_), do: "📁"

  defp format_size(bytes) when bytes < 1_024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp upload_error_message(:too_large),        do: "Archivo muy grande"
  defp upload_error_message(:not_accepted),     do: "Formato no permitido"
  defp upload_error_message(:too_many_files),   do: "Demasiados archivos"
  defp upload_error_message(_),                 do: "Error al subir"
end
