defmodule FileProcessorWeb.ExecutionShowLive do
  use FileProcessorWeb, :live_view

  alias FileProcessor.Executions
  alias FileProcessorWeb.ExecutionHTML

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    execution = Executions.get_execution!(id)

    # Parseamos una sola vez y reutilizamos para el summary
    files   = ExecutionHTML.parse_execution_files(execution)
    summary = build_summary(execution, files)

    benchmark_data =
      if execution.mode == "benchmark" do
        ExecutionHTML.extract_benchmark_data(execution.result)
      else
        nil
      end

    {:ok,
     socket
     |> assign(:execution, execution)
     |> assign(:summary, summary)
     |> assign(:files, files)
     |> assign(:benchmark_data, benchmark_data)}
  end

  # ---------------------------------------------------------------------------
  # Privadas
  # ---------------------------------------------------------------------------

  defp build_summary(execution, files) do
    total_files = execution.files |> String.split(",") |> Enum.map(&String.trim/1) |> length()
    successes   = Enum.count(files, fn f -> not f.has_error end)
    errors      = Enum.count(files, fn f -> f.has_error end)

    %{
      total_files: total_files,
      total_time:  execution.total_time,
      successes:   successes,
      errors:      errors
    }
  end
end
