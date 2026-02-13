defmodule ProcesadorArchivos.Worker do
  @moduledoc """
  Worker process for parallel file processing.

  This module implements worker processes that handle individual file processing
  in parallel. Each worker runs in its own process and sends results back to
  the coordinator when finished.

  ## Features

  - Asynchronous file processing
  - Support for CSV, JSON, and LOG file formats
  - Integration with CsvParser, JsonParser, and LogParser modules
  - Silent operation (no console output)
  - Structured error handling

  ## Functions

  ### Public Functions
  - `start/3` - Spawns a new worker process

  ### Private Functions
  - `process_file/1` - Processes individual file based on extension
  """

  @doc """
  Spawns a new worker process to process a file.

  Creates a new Elixir process that processes the specified file and sends
  the result back to the coordinator process.

  ## Parameters
    - `file_path`: Full path to the file to process
    - `coordinator_pid`: Process ID (PID) of the coordinator that will receive results
    - `_verbose`: Boolean flag for verbose output (currently unused, kept for compatibility)

  ## Returns
    - PID of the newly spawned worker process

  ## Communication
    - Uses: `spawn/1` to create new process
    - Calls: `process_file/1` to actually process the file
    - Sends message: `{:result, worker_pid, file_path, result}` to coordinator

  ## Message Format
    The worker sends a message to the coordinator with the following tuple:
    - First element: atom `:result` (identifies message type)
    - Second element: PID of the worker itself (`self()`)
    - Third element: Original file path (`file_path`)
    - Fourth element: Processing result map

  ## Example
      iex> coordinator = self()
      iex> worker_pid = Worker.start("data/file.csv", coordinator, false)
      #PID<0.123.0>

      # Coordinator will eventually receive:
      # {:result, #PID<0.123.0>, "data/file.csv", %{...}}
  """
  def start(file_path, coordinator_pid, _verbose \\ false) do
    # COMPLETAMENTE SILENCIOSO - sin IO.puts
    # spawn/1 creates a new process that runs the given function
    spawn(fn ->
      # Process the file in this new process
      result = process_file(file_path)

      # Send result back to coordinator
      # send/2 sends a message to the specified process (coordinator_pid)
      # Message format: {:result, worker_pid, file_path, result}
      send(coordinator_pid, {:result, self(), file_path, result})
    end)
  end

  # Processes an individual file based on its extension.
  #
  # ## Parameters
  #   - `file_path`: Full path to the file to process
  #
  # ## Returns
  #   - Map with processing results containing:
  #     - `:type` - File type (:csv, :json, :log, :unknown)
  #     - `:status` - Processing status (:success, :error)
  #     - `:file_name` - Base name of the file (without path)
  #     - `:processed_by` - PID of worker that processed the file
  #     - For success: Additional metrics specific to file type
  #     - For error: `:error` field with reason
  #
  # ## Communication
  #   - Uses: `Path.extname/1` to determine file type
  #   - Calls: `CsvParser.process/1`, `JsonParser.process/1`, `LogParser.process/1`
  #   - Called by: `start/3` via anonymous function in spawned process
  #
  # ## Note
  #   - This function runs in the worker process, not the coordinator process
  #   - It's completely silent (no IO.puts) to avoid console clutter in parallel mode
  defp process_file(file_path) do
    # Determine file type by extension and dispatch to appropriate parser
    case Path.extname(file_path) do
      # Process CSV files using CsvParser module
      ".csv" ->
        case CsvParser.process(file_path) do
          # Success case - merge parser metrics with standard result structure
          {:ok, metrics} ->
            Map.merge(metrics, %{
              type: :csv,
              status: :success,
              file_name: Path.basename(file_path),
              processed_by: inspect(self())  # Convert PID to string for readability
            })

          # Error case - create error result structure
          {:error, reason} ->
            %{
              type: :csv,
              status: :error,
              file_name: Path.basename(file_path),
              error: reason,
              processed_by: inspect(self())
            }
        end

      # Process JSON files using JsonParser module
      ".json" ->
        case JsonParser.process(file_path) do
          # Success case
          {:ok, metrics} ->
            Map.merge(metrics, %{
              type: :json,
              status: :success,
              file_name: Path.basename(file_path),
              processed_by: inspect(self())
            })

          # Error case
          {:error, reason} ->
            %{
              type: :json,
              status: :error,
              file_name: Path.basename(file_path),
              error: reason,
              processed_by: inspect(self())
            }
        end

      # Process LOG files using LogParser module
      ".log" ->
        case LogParser.process(file_path) do
          # Success case
          {:ok, metrics} ->
            Map.merge(metrics, %{
              type: :log,
              status: :success,
              file_name: Path.basename(file_path),
              processed_by: inspect(self())
            })

          # Error case
          {:error, reason} ->
            %{
              type: :log,
              status: :error,
              file_name: Path.basename(file_path),
              error: reason,
              processed_by: inspect(self())
            }
        end

      # Unknown file type - return error result
      _ ->
        %{
          type: :unknown,
          status: :error,
          file_name: Path.basename(file_path),
          error: "Unsupported file type",
          processed_by: inspect(self())
        }
    end
  end
end
