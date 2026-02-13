defmodule ProcesadorArchivos do
  @moduledoc """
  Main module for file processing.

  Supports both sequential (Delivery 1), parallel (Delivery 2) and error handling (Delivery 3) modes.
  This module serves as the main entry point for processing files in different formats
  (CSV, JSON, LOG) and modes (sequential, parallel, benchmark).

  ## Main Functions

  ### Sequential Processing (Delivery 1)
  - `process_files/1` - Process files sequentially with basic reporting
  - `process_file/1` - Process single file based on extension

  ### Parallel Processing (Delivery 2)
  - `process_parallel/1` - Process files in parallel using Coordinator/Worker pattern
  - `process_folder_parallel/1` - Process folder files in parallel
  - `benchmark/2` - Compare sequential vs parallel performance

  ### Error Handling (Delivery 3)
  - `procesar_con_manejo_errores/2` - Process file with detailed error handling

  ### Configurable Functions
  - `process_files_with_config/2` - Sequential processing with configuration
  - `process_parallel_with_config/2` - Parallel processing with configuration

  ### Internal Functions
  - Various private functions for report generation and metrics calculation
  """

  # ============================================================================
  # DELIVERY 1 FUNCTIONS (SEQUENTIAL PROCESSING)
  # ============================================================================

  @doc """
  Main public function for sequential file processing.

  Processes all files in a folder sequentially, generating a report with results.

  ## Parameters
    - `folder`: Path to folder containing files to process (default: "data/valid")

  ## Returns
    - `{:ok, results}` on success, where results is a list of processing results
    - `{:error, reason}` on failure

  ## Communication
    - Uses: `File.dir?/1`, `File.ls/1`, `Path.join/2`, `:os.system_time/1`
    - Calls: `process_file/1` for each file
    - Calls: `create_report/4` to generate report
    - Calls private parsers: `process_csv_private/1`, `process_json_private/1`, `process_log_private/1`

  ## Example
      iex> ProcesadorArchivos.process_files("data/valid")
      {:ok, [%{type: :csv, status: :success, ...}, ...]}
  """
  def process_files(folder \\ "data/valid") do
    # Create separator line for output formatting
    separator = String.duplicate("=", 50)
    IO.puts(separator)
    IO.puts("FILE PROCESSOR - SEQUENTIAL MODE")
    IO.puts(separator)

    # Record start time for performance measurement
    start_time = :os.system_time(:millisecond)

    # Check if folder exists
    if File.dir?(folder) do
      IO.puts("Processing folder: #{folder}")

      # List files in folder
      case File.ls(folder) do
        {:ok, files} ->
          IO.puts("Found #{length(files)} files")

          # Process each file sequentially using Enum.map
          results =
            Enum.map(files, fn file_name ->
              # Create full path by joining folder and filename
              file_path = Path.join(folder, file_name)
              # Process individual file
              process_file(file_path)
            end)

          # Calculate total processing time
          end_time = :os.system_time(:millisecond)
          total_time = end_time - start_time

          # SOLO GENERAR REPORTE SECUENCIAL
          # Create report file with results and timing
          report_file = create_report(results, total_time, folder, :sequential)

          # Display report location
          IO.puts("\n#{String.duplicate("=", 50)}")
          IO.puts("Sequential report saved to: #{report_file}")
          IO.puts(String.duplicate("=", 50))

          # Return success with results
          {:ok, results}

        {:error, reason} ->
          IO.puts("ERROR reading folder: #{reason}")
          {:error, reason}
      end
    else
      IO.puts("ERROR: Folder '#{folder}' not found")
      {:error, "Folder not found"}
    end
  end

  @doc """
  Processes a single file based on its extension.

  Dispatches to appropriate parser based on file extension.
  Returns result map with type, status, and metrics or error information.

  ## Parameters
    - `file_path`: Full path to the file to process

  ## Returns
    - Map with processing result containing:
      - `:type` - File type (:csv, :json, :log, :unknown)
      - `:status` - Processing status (:success, :error)
      - `:file_name` - Base name of the file
      - For success: metrics specific to file type
      - For error: `:error` field with reason

  ## Communication
    - Uses: `Path.extname/1` to determine file type
    - Calls private functions: `process_csv_private/1`, `process_json_private/1`, `process_log_private/1`
    - Called by: `process_files/1`, `process_files_with_config/2`

  ## Example
      iex> ProcesadorArchivos.process_file("data/file.csv")
      %{type: :csv, status: :success, file_name: "file.csv", total_sales: 1500.75, ...}
  """
  def process_file(file_path) do
    # Determine file type by extension and dispatch to appropriate parser
    case Path.extname(file_path) do
      ".csv" ->
        # Process CSV file using CsvParser module
        process_csv_private(file_path)

      ".json" ->
        # Process JSON file using JsonParser module
        process_json_private(file_path)

      ".log" ->
        # Process LOG file using LogParser module
        process_log_private(file_path)

      _ ->
        # Unknown file type - return error result
        %{
          type: :unknown,
          file_name: Path.basename(file_path),
          status: :error,
          error: "Unsupported file type"
        }
    end
  end

  # Private function to process CSV file using CsvParser
  #
  # ## Parameters
  #   - `file_path`: Path to CSV file
  #
  # ## Returns
  #   - Map with CSV metrics on success
  #   - Map with error information on failure
  #
  # ## Communication
  #   - Calls: `CsvParser.process/1`
  #   - Called by: `process_file/1`
  defp process_csv_private(file_path) do
    case CsvParser.process(file_path) do
      {:ok, metrics} ->
        # Merge parser metrics with standard result structure
        Map.merge(metrics, %{type: :csv, status: :success})

      {:error, reason} ->
        # Return error structure for CSV processing failure
        %{
          type: :csv,
          file_name: Path.basename(file_path),
          status: :error,
          error: reason
        }
    end
  end

  # Public function to process CSV (for compatibility with other functions)
  #
  # ## Parameters
  #   - `file_path`: Path to CSV file
  #
  # ## Returns
  #   - Same as `process_csv_private/1`
  #
  # ## Note: This is a wrapper that delegates to the private function
  def process_csv(file_path) do
    process_csv_private(file_path)
  end

  # Private function to process JSON file using JsonParser
  #
  # ## Parameters
  #   - `file_path`: Path to JSON file
  #
  # ## Returns
  #   - Map with JSON metrics on success
  #   - Map with error information on failure
  #
  # ## Communication
  #   - Calls: `JsonParser.process/1`
  #   - Called by: `process_file/1`
  defp process_json_private(file_path) do
    case JsonParser.process(file_path) do
      {:ok, metrics} ->
        # Merge parser metrics with standard result structure
        Map.merge(metrics, %{type: :json, status: :success})

      {:error, reason} ->
        # Return error structure for JSON processing failure
        %{
          type: :json,
          file_name: Path.basename(file_path),
          status: :error,
          error: reason
        }
    end
  end

  # Private function to process LOG file using LogParser
  #
  # ## Parameters
  #   - `file_path`: Path to LOG file
  #
  # ## Returns
  #   - Map with LOG metrics on success
  #   - Map with error information on failure
  #
  # ## Communication
  #   - Calls: `LogParser.process/1`
  #   - Called by: `process_file/1`
  defp process_log_private(file_path) do
    case LogParser.process(file_path) do
      {:ok, metrics} ->
        # Merge parser metrics with standard result structure
        Map.merge(metrics, %{type: :log, status: :success})

      {:error, reason} ->
        # Return error structure for LOG processing failure
        %{
          type: :log,
          file_name: Path.basename(file_path),
          status: :error,
          error: reason
        }
    end
  end

  # ============================================================================
  # PARALLEL PROCESSING FUNCTIONS - COMPLETELY SILENT
  # ============================================================================

  @doc """
  Process files in parallel using Coordinator/Worker pattern.

  Uses `ProcesadorArchivos.Coordinator` to manage parallel processing
  of multiple files simultaneously. Each file is processed by a separate worker.

  ## Parameters
    - `files`: List of file paths to process in parallel

  ## Returns
    - Map with processing results:
      - `:results` - List of processing results for each file
      - `:total_time` - Total processing time in milliseconds
      - `:successes` - Number of successfully processed files
      - `:errors` - Number of files with errors
      - `:report_file` - Path to generated report file

  ## Communication
    - Uses: `:timer.tc/1` for precise timing
    - Calls: `ProcesadorArchivos.Coordinator.start/2` to coordinate parallel processing
    - Calls: `create_report/5` to generate parallel processing report

  ## Example
      iex> files = ["file1.csv", "file2.json"]
      iex> ProcesadorArchivos.process_parallel(files)
      %{
        results: [%{...}, %{...}],
        total_time: 1250,
        successes: 2,
        errors: 0,
        report_file: "output/report_parallel_..."
      }
  """
  def process_parallel(files) do
    # Use :timer.tc for precise and consistent timing measurement
    # :timer.tc returns {time_in_microseconds, function_result}
    {time_us, results_map} =
      :timer.tc(fn ->
        # Start Coordinator with files and silent configuration
        ProcesadorArchivos.Coordinator.start(files, %{
          timeout: 5000,    # 5 second timeout per worker
          verbose: false    # Silent mode (no console output)
        })
      end)

    # Convert microseconds to milliseconds
    total_time_ms = div(time_us, 1000)

    # Extract results from map (Coordinator returns map of file_path -> result)
    results = Map.values(results_map)

    # Count successes and errors
    successes = Enum.count(results, &(&1[:status] == :success))
    errors = length(results) - successes

    # SOLO GENERAR REPORTE para modo paralelo
    # Create report specifically for parallel processing
    report_file =
      create_report(
        results,
        total_time_ms,
        "parallel processing",
        :parallel,
        length(files)  # Pass number of files as worker count info
      )

    # Display report location
    IO.puts("\n#{String.duplicate("=", 50)}")
    IO.puts("Parallel report saved to: #{report_file}")
    IO.puts(String.duplicate("=", 50))

    # Return comprehensive results map
    %{
      results: results,
      total_time: total_time_ms,
      successes: successes,
      errors: errors,
      report_file: report_file
    }
  end

  @doc """
  Process all files in a folder in parallel.

  Convenience wrapper that lists folder contents and processes them in parallel.

  ## Parameters
    - `folder`: Path to folder containing files (default: "data/valid")

  ## Returns
    - List of processing results on success
    - `{:error, reason}` on failure

  ## Communication
    - Uses: `File.dir?/1`, `File.ls/1`, `Path.join/2`
    - Calls: `process_parallel/1` for actual parallel processing

  ## Example
      iex> ProcesadorArchivos.process_folder_parallel("data/valid")
      [%{...}, %{...}, ...]
  """
  def process_folder_parallel(folder \\ "data/valid") do
    if File.dir?(folder) do
      case File.ls(folder) do
        {:ok, files} ->
          IO.puts("Found #{length(files)} files in #{folder}")

          # Convert filenames to full paths
          full_paths =
            Enum.map(files, fn file_name ->
              Path.join(folder, file_name)
            end)

          # Process all files in parallel
          result = process_parallel(full_paths)

          # Display summary information
          IO.puts("Parallel processing completed in #{result.total_time}ms")
          IO.puts("Results: #{result.successes} successful, #{result.errors} errors")

          # Return just the results list (not the full result map)
          result.results

        {:error, reason} ->
          IO.puts("ERROR reading folder: #{reason}")
          {:error, reason}
      end
    else
      IO.puts("ERROR: Folder '#{folder}' not found")
      {:error, "Folder not found"}
    end
  end

  @doc """
  Compare sequential vs parallel processing performance.

  Runs both sequential and parallel processing on the same files
  and compares execution times. Generates a comprehensive benchmark report.

  ## Parameters
    - `folder`: Path to folder with files to benchmark (default: "data/valid")
    - `_config`: Configuration map (currently unused, kept for compatibility)

  ## Returns
    - Map with benchmark results:
      - `:sequential_ms` - Sequential processing time in milliseconds
      - `:parallel_ms` - Parallel processing time in milliseconds
      - `:improvement` - Speed improvement factor (sequential/parallel)
      - `:percent_faster` - Percentage improvement
      - `:files_count` - Number of files processed
      - `:benchmark_report` - Path to generated benchmark report

  ## Communication
    - Uses: `File.dir?/1`, `File.ls/1`, `:timer.tc/1`, `Path.join/2`
    - Calls: `process_file/1` for sequential mode
    - Calls: `ProcesadorArchivos.Coordinator.start/2` for parallel mode
    - Calls: `generate_benchmark_report/8` for report generation

  ## Example
      iex> ProcesadorArchivos.benchmark("data/valid")
      %{
        sequential_ms: 2450,
        parallel_ms: 850,
        improvement: 2.88,
        percent_faster: 65.3,
        files_count: 10,
        benchmark_report: "output/report_benchmark_..."
      }
  """
  def benchmark(folder \\ "data/valid", _config \\ %{}) do
    # Validate folder exists
    unless File.dir?(folder) do
      IO.puts("ERROR: Folder '#{folder}' does not exist")
      {:error, "Folder not found"}
    end

    # List files in folder
    case File.ls(folder) do
      {:ok, []} ->
        IO.puts("WARNING: Empty folder, no files for benchmark")
        %{sequential_ms: 0, parallel_ms: 0, improvement: 0.0, files_count: 0}

      {:ok, files} ->
        IO.puts("\nBENCHMARK: Sequential vs Parallel")
        IO.puts("Files: #{length(files)}")
        IO.puts("")

        # Create full paths for all files
        full_paths = Enum.map(files, &Path.join(folder, &1))

        # ============ SECUENTIAL MODE ============
        IO.puts("1. Sequential mode...")

        # Time sequential processing
        {seq_time_us, seq_results} =
          :timer.tc(fn ->
            # Process each file sequentially using Enum.map
            full_paths
            |> Enum.map(&process_file/1)
          end)

        seq_time_ms = div(seq_time_us, 1000)
        IO.puts("   Time: #{seq_time_ms} ms")

        # ============ PARALLEL MODE ============
        IO.puts("\n2. Parallel mode...")

        # Time parallel processing using Coordinator
        {par_time_us, results_map} =
          :timer.tc(fn ->
            ProcesadorArchivos.Coordinator.start(full_paths, %{
              timeout: 5000,
              verbose: false
            })
          end)

        par_time_ms = div(par_time_us, 1000)
        par_results = Map.values(results_map)
        IO.puts("   Time: #{par_time_ms} ms")

        # ============ CALCULATE RESULTS ============
        # Calculate improvement factor (sequential_time / parallel_time)
        improvement =
          if par_time_ms > 0,
            do: Float.round(seq_time_ms / par_time_ms, 2),
            else: 0.0

        # Calculate percentage improvement
        percent_faster =
          if seq_time_ms > 0,
            do: Float.round((1 - par_time_ms / seq_time_ms) * 100, 1),
            else: 0.0

        # SOLO GENERAR REPORTE DE BENCHMARK COMPARATIVO
        # Generate comprehensive benchmark report
        report_file =
          generate_benchmark_report(
            seq_results,
            par_results,
            seq_time_ms,
            par_time_ms,
            improvement,
            percent_faster,
            folder,
            length(files)
          )

        # ============ SHOW RESULTS ============
        IO.puts("\nRESULTS:")
        IO.puts("Sequential: #{seq_time_ms} ms")
        IO.puts("Parallel:   #{par_time_ms} ms")
        IO.puts("")

        # Display improvement message based on improvement factor
        if improvement >= 1.1 do
          IO.puts("Parallel is #{improvement}x faster")
          IO.puts("(#{percent_faster}% improvement)")
        else
          IO.puts("Improvement is minimal (#{improvement}x)")
        end

        # Return benchmark results
        %{
          sequential_ms: seq_time_ms,
          parallel_ms: par_time_ms,
          improvement: improvement,
          percent_faster: percent_faster,
          files_count: length(files),
          benchmark_report: report_file
        }

      {:error, reason} ->
        IO.puts("ERROR reading folder: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Benchmark with configuration (compatibility wrapper).

  ## Parameters
    - `folder`: Path to folder with files
    - `_config`: Configuration map (currently unused)

  ## Returns
    - Same as `benchmark/1`

  ## Note: Currently just calls benchmark/1, kept for API compatibility
  """
  def benchmark_with_config(folder, _config \\ %{}) do
    benchmark(folder)
  end

  # ============================================================================
  # FUNCIÓN PARA REPORTE DE BENCHMARK (PRIVADA)
  # ============================================================================

  # Generates comprehensive benchmark report comparing sequential vs parallel
  #
  # ## Parameters
  #   - `seq_results`: List of sequential processing results
  #   - `par_results`: List of parallel processing results
  #   - `seq_time`: Sequential processing time in ms
  #   - `par_time`: Parallel processing time in ms
  #   - `improvement`: Speed improvement factor
  #   - `percent_faster`: Percentage improvement
  #   - `folder`: Folder path that was processed
  #   - `files_count`: Number of files processed
  #
  # ## Returns
  #   - String: Path to generated report file
  #
  # ## Communication
  #   - Uses: `File.mkdir_p!/1`, `DateTime.utc_now/0`, `System.schedulers_online/0`
  #   - Called by: `benchmark/2`
  defp generate_benchmark_report(
         seq_results,
         par_results,
         seq_time,
         par_time,
         improvement,
         percent_faster,
         folder,
         files_count
       ) do
    # Ensure output directory exists
    File.mkdir_p!("output")

    workers_used = files_count  # One worker per file

    # Create timestamp for unique filename
    timestamp =
      DateTime.utc_now()
      |> DateTime.to_string()
      |> String.replace(" ", "_")
      |> String.replace(":", "-")

    report_file = "output/report_benchmark_#{timestamp}.txt"

    # Calculate statistics for both modes
    seq_successes = Enum.count(seq_results, &(&1[:status] == :success))
    seq_errors = Enum.count(seq_results, &(&1[:status] == :error))
    par_successes = Enum.count(par_results, &(&1[:status] == :success))
    par_errors = Enum.count(par_results, &(&1[:status] == :error))

    # Count files by type for sequential mode
    seq_csv = Enum.count(seq_results, &(&1[:type] == :csv))
    seq_json = Enum.count(seq_results, &(&1[:type] == :json))
    seq_log = Enum.count(seq_results, &(&1[:type] == :log))

    # Count files by type for parallel mode
    par_csv = Enum.count(par_results, &(&1[:type] == :csv))
    par_json = Enum.count(par_results, &(&1[:type] == :json))
    par_log = Enum.count(par_results, &(&1[:type] == :log))

    # Generate comprehensive report content
    content = """

    ================================================================================
                            BENCHMARK CONFIGURATION
    ================================================================================

    PARALLELISM CONFIGURATION:
    - Total files: #{files_count}
    - Workers used: #{workers_used} (one per file)
    - System cores: #{System.schedulers_online()}
    - Workers/files ratio: #{workers_used}/#{files_count}

    ================================================================================
                          BENCHMARK REPORT - COMPARATIVE
    ================================================================================

    Generation date: #{timestamp}
    Processed folder: #{folder}
    Total files: #{files_count}

    ================================================================================
                              PERFORMANCE RESULTS
    ================================================================================

    EXECUTION TIMES:
    - Sequential Mode: #{seq_time} milliseconds
    - Parallel Mode:   #{par_time} milliseconds
    - Improvement factor: #{improvement}x faster
    - Improvement percentage: #{percent_faster}%

    ================================================================================
                            PROCESSING STATISTICS
    ================================================================================

    SEQUENTIAL MODE:
    - Total files: #{length(seq_results)}
    - Successful: #{seq_successes}
    - With errors: #{seq_errors}
    - Success rate: #{if length(seq_results) > 0, do: Float.round(seq_successes / length(seq_results) * 100, 1), else: 0}%

    Distribution by type:
      - CSV:  #{seq_csv} files
      - JSON: #{seq_json} files
      - LOG:  #{seq_log} files

    PARALLEL MODE:
    - Total files: #{length(par_results)}
    - Successful: #{par_successes}
    - With errors: #{par_errors}
    - Success rate: #{if length(par_results) > 0, do: Float.round(par_successes / length(par_results) * 100, 1), else: 0}%

    Distribution by type:
      - CSV:  #{par_csv} files
      - JSON: #{par_json} files
      - LOG:  #{par_log} files

    ================================================================================
                                COMPARATIVE ANALYSIS
    ================================================================================

    PERFORMANCE DIFFERENCE:
    - Time saved: #{abs(seq_time - par_time)} ms
    - Relative efficiency: #{improvement}x

    RESULTS DIFFERENCE:
    - Additional successful files in parallel: #{par_successes - seq_successes}
    - Error difference: #{par_errors - seq_errors}

    ================================================================================
                              RECOMMENDATIONS
    ================================================================================

    #{if improvement >= 1.5 do
      " MAIN RECOMMENDATION: Use PARALLEL MODE\n" <>
      "  Parallel processing is significantly faster (#{improvement}x)\n" <>
      "  and maintains the same reliability in results."
    else
      " MAIN RECOMMENDATION: Use SEQUENTIAL MODE\n" <>
      "  Parallel mode improvement is minimal (#{improvement}x)\n" <>
      "  and doesn't justify process management overhead."
    end}

    ================================================================================
                                   CONCLUSIONS
    ================================================================================

    1. #{if seq_successes == par_successes, do: "Both modes produced consistent results", else: "There are differences in results between modes"}
    2. #{if improvement >= 1.1, do: "Parallelism offers performance advantages", else: "Parallelism overhead outweighs its benefits"}
    3. #{if seq_errors == 0 and par_errors == 0, do: "Reliable processing without errors", else: "Errors were detected that require attention"}

    ================================================================================
                                END OF REPORT
    ================================================================================
    """

    # Write report to file
    File.write!(report_file, content)

    # Display report location
    IO.puts("\n#{String.duplicate("=", 50)}")
    IO.puts("Benchmark report saved to: #{report_file}")
    IO.puts(String.duplicate("=", 50))

    report_file
  end

  # ============================================================================
  # REPORT FUNCTIONS (PRIVADAS)
  # ============================================================================

  # Creates report file with processing results
  #
  # ## Parameters
  #   - `results`: List of processing results
  #   - `total_time`: Total processing time in ms
  #   - `folder`: Folder that was processed
  #   - `mode`: Processing mode (:parallel or :sequential)
  #   - `workers_count`: Number of workers used (optional, for parallel mode)
  #
  # ## Returns
  #   - String: Path to generated report file
  #
  # ## Communication
  #   - Uses: `File.mkdir_p!/1`, `DateTime.utc_now/0`, `File.write!/2`
  #   - Calls: `generate_report_content/5`
  #   - Called by: `process_files/1`, `process_parallel/1`, `process_files_with_config/2`
  defp create_report(results, total_time, folder, mode, workers_count \\ nil) do
    # Create timestamp for unique filename
    timestamp =
      DateTime.utc_now() |> DateTime.to_string() |> String.replace(":", "-")

    # Convert atom mode to string for filename
    mode_str =
      case mode do
        :parallel -> "parallel"
        :sequential -> "sequential"
      end

    # Create report filename
    report_file = "output/report_#{mode_str}_#{timestamp}.txt"

    # Ensure output directory exists
    File.mkdir_p!("output")

    # Generate report content
    report_content =
      generate_report_content(
        results,
        total_time,
        folder,
        mode_str,
        workers_count
      )

    # Write content to file
    File.write!(report_file, report_content)

    report_file
  end

  # Generates textual report content
  #
  # ## Parameters
  #   - `results`: List of processing results
  #   - `total_time`: Total processing time in ms
  #   - `folder`: Folder that was processed
  #   - `mode_str`: Processing mode as string ("parallel" or "sequential")
  #   - `workers_info`: Number of workers used (for parallel mode)
  #
  # ## Returns
  #   - String: Formatted report content
  #
  # ## Communication
  #   - Calls: `generate_metrics_section/2`, `generate_success_metrics/2`
  #   - Called by: `create_report/5`
  defp generate_report_content(
         results,
         total_time,
         folder,
         mode_str,
         workers_info
       ) do
    # Calculate basic statistics
    successes = Enum.count(results, &(&1[:status] == :success))
    errors = Enum.count(results, &(&1[:status] == :error))

    # Filter results by file type
    csv_results = Enum.filter(results, &(&1[:type] == :csv))
    json_results = Enum.filter(results, &(&1[:type] == :json))
    log_results = Enum.filter(results, &(&1[:type] == :log))

    # Calculate success rate
    success_rate =
      if length(results) > 0 do
        Float.round(successes / length(results) * 100, 1)
      else
        0.0
      end

    # Generate mode description text
    mode_text =
      if mode_str == "parallel" do
        if workers_info do
          "Parallel (using #{workers_info} workers - one per file)"
        else
          "Parallel (Coordinator/Worker mode)"
        end
      else
        "Sequential"
      end

    # Build report lines
    lines = [
      "================================================================================\n" <>
        "                    FILE PROCESSING REPORT\n" <>
        "================================================================================\n",
      "Generation date: #{DateTime.utc_now()}",
      "Processed directory: #{folder}",
      "Processing mode: #{mode_text}\n"
    ]

    # Add parallelism configuration section for parallel mode
    lines =
      if mode_str == "parallel" and workers_info do
        lines ++
          [
            "--------------------------------------------------------------------------------\n" <>
              "PARALLELISM CONFIGURATION\n" <>
              "--------------------------------------------------------------------------------",
            "Workers used: #{workers_info}",
            "Files processed: #{length(results)}",
            "Workers/files ratio: #{workers_info}/#{length(results)}",
            ""
          ]
      else
        lines
      end

    # Add summary section
    lines =
      lines ++
        [
          "--------------------------------------------------------------------------------\n" <>
            "SUMMARY\n" <>
            "--------------------------------------------------------------------------------",
          "Total files processed: #{length(results)}",
          "  - CSV files: #{length(csv_results)}",
          "  - JSON files: #{length(json_results)}",
          "  - LOG files: #{length(log_results)}",
          "",
          "Total processing time: #{total_time} ms",
          "Successful files: #{successes}",
          "Files with errors: #{errors}",
          "Success rate: #{success_rate}%",
          ""
        ]

    # Add metrics sections for each file type
    lines = lines ++ generate_metrics_section("CSV", csv_results)
    lines = lines ++ generate_metrics_section("JSON", json_results)
    lines = lines ++ generate_metrics_section("LOG", log_results)

    # Add error details section if there were errors
    error_details =
      if errors > 0 do
        error_lines = [
          "\n--------------------------------------------------------------------------------\n" <>
            "DETECTED ERRORS\n" <>
            "--------------------------------------------------------------------------------"
        ]

        # Generate error details for each failed file
        details =
          Enum.map(results, fn result ->
            if result[:status] == :error do
              "✗ #{result[:file_name]}: #{result[:error]}"
            end
          end)
          |> Enum.filter(& &1)

        error_lines ++ details
      else
        []
      end

    # Combine all sections
    all_lines =
      lines ++
        error_details ++
        [
          "\n================================================================================\n" <>
            "                           END OF REPORT\n" <>
            "================================================================================"
        ]

    # Join lines with newlines
    Enum.join(all_lines, "\n")
  end

  # Generates metrics section for a specific file type
  #
  # ## Parameters
  #   - `type`: File type string ("CSV", "JSON", "LOG")
  #   - `results`: List of results for that file type
  #
  # ## Returns
  #   - List of strings forming the metrics section
  #
  # ## Communication
  #   - Calls: `generate_success_metrics/2` for each successful result
  #   - Called by: `generate_report_content/5`
  defp generate_metrics_section(type, results) do
    if Enum.empty?(results) do
      []
    else
      section = [
        "\n--------------------------------------------------------------------------------\n" <>
          "#{String.upcase(type)} FILE METRICS\n" <>
          "--------------------------------------------------------------------------------"
      ]

      # Generate metrics for each file
      metrics =
        Enum.map(results, fn result ->
          case result[:status] do
            :success ->
              generate_success_metrics(type, result)

            :error ->
              "\n[#{result.file_name}]" <>
                "\n  - ERROR: #{result.error}"

            _ ->
              "\n[#{result.file_name}]" <>
                "\n  - Unknown state"
          end
        end)

      section ++ metrics
    end
  end

  # Generates specific format for successful CSV metrics
  #
  # ## Parameters
  #   - `type`: Always "CSV"
  #   - `result`: CSV processing result map
  #
  # ## Returns
  #   - String: Formatted CSV metrics
  defp generate_success_metrics("CSV", result) do
    "\n[#{result.file_name}]" <>
      "\n  - Valid records: #{result.valid_records}" <>
      "\n  - Unique products: #{result.unique_products}" <>
      "\n  - Total sales: $#{:erlang.float_to_binary(result.total_sales, decimals: 2)}"
  end

  # Generates specific format for successful JSON metrics
  #
  # ## Parameters
  #   - `type`: Always "JSON"
  #   - `result`: JSON processing result map
  #
  # ## Returns
  #   - String: Formatted JSON metrics
  defp generate_success_metrics("JSON", result) do
    "\n[#{result.file_name}]" <>
      "\n  - Total users: #{result.total_users}" <>
      "\n  - Active users: #{result.active_users}" <>
      "\n  - Total sessions: #{result.total_sessions}"
  end

  # Generates specific format for successful LOG metrics
  #
  # ## Parameters
  #   - `type`: Always "LOG"
  #   - `result`: LOG processing result map
  #
  # ## Returns
  #   - String: Formatted LOG metrics
  defp generate_success_metrics("LOG", result) do
    "\n[#{result.file_name}]" <>
      "\n  - Total lines: #{result.total_lines}" <>
      "\n  - Distribution: DEBUG(#{result.debug}), INFO(#{result.info}), WARN(#{result.warn}), ERROR(#{result.error}), FATAL(#{result.fatal})"
  end

  # ============================================================================
  # CONFIGURABLE FUNCTIONS (for CLI and other uses)
  # ============================================================================

  @doc """
  Processes files in sequential mode with configuration.

  ## Parameters
    - `folder`: Path to folder containing files
    - `config`: Configuration map with:
        - `:timeout` - Timeout per file (unused in sequential mode)
        - `:generate_report` - Whether to generate report (default: true)
        - `:verbose` - Whether to show detailed output (default: false)

  ## Returns
    - `{:ok, results}` on success
    - `{:error, reason}` on failure

  ## Communication
    - Uses: `File.dir?/1`, `File.ls/1`, `Path.join/2`, `:os.system_time/1`
    - Calls: `process_file/1`, `create_report/4`, `print_result_summary/1`
  """
  def process_files_with_config(folder, config \\ %{}) do
    # Default configuration
    default_config = %{
      timeout: 5000,
      generate_report: true,
      verbose: false
    }

    # Merge provided config with defaults
    config = Map.merge(default_config, config)

    # Start timing
    start_time = :os.system_time(:millisecond)

    if File.dir?(folder) do
      case File.ls(folder) do
        {:ok, files} ->
          # Show file count if verbose
          if config.verbose do
            IO.puts("Found #{length(files)} files")
          end

          # Process each file
          results =
            files
            |> Enum.map(&Path.join(folder, &1))
            |> Enum.map(fn file_path ->
              if config.verbose do
                IO.puts("Processing #{Path.basename(file_path)}")
              end

              result = process_file(file_path)

              if config.verbose do
                print_result_summary(result)
              end

              result
            end)

          # Calculate total time
          end_time = :os.system_time(:millisecond)
          total_time = end_time - start_time

          # Generate report if enabled
          if config.generate_report do
            report_file =
              create_report(results, total_time, folder, :sequential)

            IO.puts("\nReport saved to: #{report_file}")
          end

          # Show total time if verbose
          if config.verbose do
            IO.puts("Total time: #{total_time}ms")
          end

          {:ok, results}

        {:error, reason} ->
          IO.puts("Error reading folder: #{reason}")
          {:error, reason}
      end
    else
      IO.puts("Error: Folder '#{folder}' not found")
      {:error, "Folder not found"}
    end
  end

  # Helper function to print result summary
  #
  # ## Parameters
  #   - `result`: Processing result map
  #
  # ## Communication
  #   - Called by: `process_files_with_config/2` when verbose mode is enabled
  defp print_result_summary(result) do
    if result[:status] == :success do
      case result[:type] do
        :csv -> IO.puts("  ✓ CSV: #{result[:valid_records]} records")
        :json -> IO.puts("  ✓ JSON: #{result[:total_users]} users")
        :log -> IO.puts("  ✓ LOG: #{result[:total_lines]} lines")
        _ -> :ok
      end
    end
  end

  @doc """
  Processes files in parallel with configuration.

  ## Parameters
    - `folder`: Path to folder containing files
    - `config`: Configuration map with:
        - `:timeout` - Timeout per worker in ms (default: 5000)
        - `:verbose` - Whether to show detailed output (default: false)
        - `:generate_report` - Whether to generate report (default: true)

  ## Returns
    - List of processing results

  ## Communication
    - Uses: `File.dir?/1`, `File.ls/1`, `Path.join/2`, `:timer.tc/1`
    - Calls: `ProcesadorArchivos.Coordinator.start/2`, `create_report/5`
  """
  def process_parallel_with_config(folder, config \\ %{}) do
    # Default configuration
    default_config = %{
      timeout: 5000,
      verbose: false,
      generate_report: true
    }

    # Merge provided config with defaults
    config = Map.merge(default_config, config)

    if File.dir?(folder) do
      case File.ls(folder) do
        {:ok, files} ->
          # Create full paths for all files
          full_paths = Enum.map(files, &Path.join(folder, &1))

          # Show start message if verbose
          if config.verbose do
            IO.puts("Processing in parallel (Coordinator/Worker mode):")
          end

          # Time parallel processing
          {time_us, results_map} =
            :timer.tc(fn ->
              ProcesadorArchivos.Coordinator.start(full_paths, config)
            end)

          total_time_ms = div(time_us, 1000)
          results = Map.values(results_map)

          # Generate report if enabled
          if config.generate_report do
            report_file =
              create_report(
                results,
                total_time_ms,
                folder,
                :parallel,
                length(full_paths)
              )

            IO.puts("\nReport saved to: #{report_file}")
          end

          # Show statistics if verbose
          if config.verbose do
            IO.puts("Total time: #{total_time_ms}ms")
            successes = Enum.count(results, &(&1[:status] == :success))
            errors = length(results) - successes
            IO.puts("Successful: #{successes}, Errors: #{errors}")
          end

          results

        {:error, reason} ->
          IO.puts("Error reading folder: #{reason}")
          []
      end
    else
      IO.puts("Error: Folder '#{folder}' not found")
      []
    end
  end

  # ============================================================================
  # DELIVERY 3 FUNCTIONS - ERROR HANDLING CON REPORTES
  # ============================================================================

  @doc """
  Processes a file with detailed error handling.

  Uses `ProcesadorArchivos.ProcesarConManejoErrores` module to process files
  with line-by-line error detection and reporting.

  ## Parameters
    - `file_path`: Path to file to process
    - `config`: Configuration map (passed to error handler)

  ## Returns
    - Map with error handling results:
      - `:estado` - Processing state (:completo, :error, :parcial)
      - `:lineas_procesadas` - Number of successfully processed lines
      - `:lineas_con_error` - Number of lines with errors
      - `:errores` - List of detailed error information
      - `:tipo_archivo` - Type of file (:csv, :json, :log)
      - `:detalles` - Additional processing details

  ## Communication
    - Calls: `ProcesadorArchivos.ProcesarConManejoErrores.procesar/2`
    - Calls: `generar_reporte_errores/2` to generate error report
  """
  def procesar_con_manejo_errores(file_path, config \\ %{}) do
    IO.puts("Processing with error handling: #{Path.basename(file_path)}")

    # Call error handling module
    result =
      ProcesadorArchivos.ProcesarConManejoErrores.procesar(file_path, config)

    case result do
      {:error, mensaje} ->
        IO.puts("Error: #{mensaje}")
        %{estado: :error, error: mensaje}

      mapa when is_map(mapa) ->
        # GENERAR REPORTE DE ERRORES
        generar_reporte_errores(mapa, file_path)
        mapa
    end
  end

  # Generates error handling report
  #
  # ## Parameters
  #   - `resultado`: Error handling result map
  #   - `file_path`: Path to processed file
  #
  # ## Returns
  #   - String: Path to generated report file
  #
  # ## Communication
  #   - Uses: `File.mkdir_p!/1`, `File.write!/2`, `DateTime.utc_now/0`
  #   - Calls type-specific content generators
  defp generar_reporte_errores(resultado, file_path) do
    # Create timestamp for unique filename
    timestamp =
      DateTime.utc_now() |> DateTime.to_string() |> String.replace(":", "-")

    # Create report filename
    report_file =
      "output/report_errores_#{Path.basename(file_path)}_#{timestamp}.txt"

    # Ensure output directory exists
    File.mkdir_p!("output")

    # Determine file type for specific formatting
    tipo_archivo = Map.get(resultado, :tipo_archivo, :desconocido)

    tipo_str =
      case tipo_archivo do
        :csv -> "CSV"
        :json -> "JSON"
        :log -> "LOG"
        _ -> "DESCONOCIDO"
      end

    # Generate content based on file type
    contenido =
      case tipo_archivo do
        :csv ->
          generar_contenido_csv(resultado, file_path, tipo_str)

        :json ->
          generar_contenido_json(resultado, file_path, tipo_str)

        :log ->
          generar_contenido_log(resultado, file_path, tipo_str)

        _ ->
          generar_contenido_generico(resultado, file_path)
      end

    # Write report to file
    File.write!(report_file, contenido)

    # Display report location
    IO.puts("\n#{String.duplicate("=", 50)}")
    IO.puts("Error handling report saved to: #{report_file}")
    IO.puts(String.duplicate("=", 50))

    report_file
  end

  # Generates CSV-specific error report content
  defp generar_contenido_csv(resultado, file_path, tipo_str) do
    detalles = Map.get(resultado, :detalles, %{})

    """
    ================================================================================
                      ERROR HANDLING REPORT - #{tipo_str}
    ================================================================================

    Generation date: #{DateTime.utc_now()}
    File: #{Path.basename(file_path)}
    Status: #{resultado.estado}
    File type: #{tipo_str}

    ================================================================================
                      PROCESSING STATISTICS
    ================================================================================

    #{if Map.has_key?(resultado, :lineas_procesadas) do
      "Total lines in file: #{resultado.total_lineas}\n" <>
      "Successfully processed lines: #{resultado.lineas_procesadas}\n" <>
      "Lines with errors: #{resultado.lineas_con_error}\n" <>
      "Success rate: #{detalles.porcentaje_exito}%\n" <>
      "Error rate: #{detalles.porcentaje_error}%"
    else
      "No line-by-line processing statistics available"
    end}

    #{if Map.has_key?(resultado, :errores) and length(resultado.errores) > 0 do
      "\n===============================================================================\n" <>
      "                    ERROR DETAILS\n" <>
      "===============================================================================\n\n" <>
      Enum.map_join(resultado.errores, "\n", fn {linea, error, contenido} ->
        "Line #{linea}: #{error}\n" <>
        "Content: #{contenido}\n" <>
        String.duplicate("-", 80)
      end)
    else
      if resultado.estado == :completo do
        "\n===============================================================================\n" <>
        "                    NO ERRORS DETECTED\n" <>
        "===============================================================================\n" <>
        "All lines were processed successfully. File is valid."
      else
        "\n===============================================================================\n" <>
        "                    UNKNOWN ERROR\n" <>
        "===============================================================================\n" <>
        "An error occurred but no specific error details are available."
      end
    end}

    #{if Map.has_key?(detalles, :recomendacion) do
      "\n===============================================================================\n" <>
      "                    RECOMMENDATIONS\n" <>
      "===============================================================================\n" <>
      "#{detalles.recomendacion}"
    else
      ""
    end}

    ================================================================================
                              END OF REPORT
    ================================================================================
    """
  end

  # Generates JSON-specific error report content
  defp generar_contenido_json(resultado, file_path, tipo_str) do
    detalles = Map.get(resultado, :detalles, %{})

    """
    ================================================================================
                      ERROR HANDLING REPORT - #{tipo_str}
    ================================================================================

    Generation date: #{DateTime.utc_now()}
    File: #{Path.basename(file_path)}
    Status: #{resultado.estado}
    File type: #{tipo_str}

    ================================================================================
                      PROCESSING DETAILS
    ================================================================================

    #{if resultado.estado == :completo do
      "JSON Structure: VALID\n" <>
      "Fields detected: #{Enum.join(detalles.campos_presentes, ", ")}\n" <>
      "Total users: #{detalles.total_usuarios}\n" <>
      "Active users: #{detalles.usuarios_activos}\n" <>
      "Total sessions: #{detalles.total_sesiones}"
    else
      "JSON Structure: INVALID\n" <>
      "Error type: #{detalles.tipo_error}\n" <>
      "Error message: #{detalles.mensaje_error}\n" <>
      "Position: #{detalles.posicion}"
    end}

    #{if Map.has_key?(detalles, :recomendacion) do
      "\n===============================================================================\n" <>
      "                    RECOMMENDATIONS\n" <>
      "===============================================================================\n" <>
      "#{detalles.recomendacion}"
    else
      ""
    end}

    ================================================================================
                              END OF REPORT
    ================================================================================
    """
  end

  # Generates LOG-specific error report content
  defp generar_contenido_log(resultado, file_path, tipo_str) do
    detalles = Map.get(resultado, :detalles, %{})
    distribucion = Map.get(detalles, :distribucion_niveles, %{})

    """
    ================================================================================
                      ERROR HANDLING REPORT - #{tipo_str}
    ================================================================================

    Generation date: #{DateTime.utc_now()}
    File: #{Path.basename(file_path)}
    Status: #{resultado.estado}
    File type: #{tipo_str}

    ================================================================================
                      PROCESSING STATISTICS
    ================================================================================

    Total lines in file: #{detalles.total_lineas}
    Valid log lines: #{resultado.lineas_procesadas}
    Invalid lines: #{resultado.lineas_con_error}
    Valid lines percentage: #{detalles.porcentaje_valido}%
    Invalid lines percentage: #{detalles.porcentaje_invalido}%

    Log level distribution:
      - DEBUG: #{distribucion.debug || 0}
      - INFO: #{distribucion.info || 0}
      - WARN: #{distribucion.warn || 0}
      - ERROR: #{distribucion.error || 0}
      - FATAL: #{distribucion.fatal || 0}

    #{if Map.has_key?(resultado, :errores) and length(resultado.errores) > 0 do
      "\n===============================================================================\n" <>
      "                    INVALID LINES DETAILS\n" <>
      "===============================================================================\n\n" <>
      Enum.map_join(resultado.errores, "\n", fn {linea, error, contenido} ->
        "Line #{linea}: #{error}\n" <>
        "Content: #{contenido}\n" <>
        String.duplicate("-", 80)
      end)
    else
      if resultado.estado == :completo do
        "\n===============================================================================\n" <>
        "                    ALL LINES VALID\n" <>
        "===============================================================================\n" <>
        "All log lines follow the expected format."
      else
        ""
      end
    end}

    #{if Map.has_key?(detalles, :recomendacion) do
      "\n===============================================================================\n" <>
      "                    RECOMMENDATIONS\n" <>
      "===============================================================================\n" <>
      "#{detalles.recomendacion}"
    else
      ""
    end}

    ================================================================================
                              END OF REPORT
    ================================================================================
    """
  end

  # Generates generic error report content
  defp generar_contenido_generico(resultado, file_path) do
    """
    ================================================================================
                      ERROR HANDLING REPORT
    ================================================================================

    Generation date: #{DateTime.utc_now()}
    File: #{Path.basename(file_path)}
    Status: #{resultado.estado}

    ================================================================================
                      ERROR DETAILS
    ================================================================================

    #{if Map.has_key?(resultado, :error) do
      "Error: #{resultado.error}"
    else
      "Unknown error occurred"
    end}

    ================================================================================
                      RECOMMENDATIONS
    ================================================================================

    Please check:
    1. File exists and is readable
    2. File format is supported (CSV, JSON, LOG)
    3. File permissions allow reading
    4. File is not corrupted

    ================================================================================
                              END OF REPORT
    ================================================================================
    """
  end
end
