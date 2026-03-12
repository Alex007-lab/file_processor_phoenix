defmodule FileProcessorWeb.ExecutionShowLive do
  use FileProcessorWeb, :live_view

  alias FileProcessor.Executions
  alias FileProcessorWeb.ExecutionHTML

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    execution = Executions.get_execution!(id)

    summary = get_execution_summary(execution)
    files = parse_execution_files(execution)

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

  # -----------------------------
  # Helpers que antes estaban en controller
  # -----------------------------

  defp get_execution_summary(execution) do
    files = parse_execution_files(execution)

    real_files =
      execution.files
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    successes =
      Enum.count(files, fn f -> not f.has_error end)

    errors =
      Enum.count(files, fn f -> f.has_error end)

    %{
      total_files: length(real_files),
      total_time: execution.total_time,
      successes: successes,
      errors: errors
    }
  end

  defp parse_execution_files(execution) do
    # reutiliza helper
    ExecutionHTML.parse_execution_files(execution)
  end
end
