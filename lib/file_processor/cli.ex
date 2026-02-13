defmodule ProcesadorArchivos.CLI do
  @moduledoc """
  Command line interface for the processor.

  This module handles command line argument parsing and dispatches
  processing tasks based on user input. It supports different processing
  modes and file/directory handling.

  ## Functions

  ### Public Functions
  - `main/1` - Main entry point for the CLI application

  ### Private Functions
  - `process_args/1` - Parses command line arguments
  - `process_files/2` - Determines file/directory processing
  - `process_directory/2` - Processes directory contents
  - `process_single_file/2` - Processes single file
  - `show_help/0` - Displays help message
  """

  @doc """
  Main entry point for the CLI application.

  This function is called when the application starts and delegates
  to the argument processing function.

  ## Parameters
    - `args`: List of command line arguments

  ## Communication
    - Calls: `process_args/1`
  """
  def main(args) do
    # Delegates argument processing to the private function
    process_args(args)
  end

  # Parses command line arguments and dispatches appropriate actions.
  #
  # Handles help requests, validates input, and prepares configuration
  # for file processing.
  #
  # ## Parameters
  #   - `args`: List of command line arguments from main/1
  #
  # ## Communication
  #   - Calls: `show_help/0`, `process_files/2`
  #   - Uses: `OptionParser.parse/2` for argument parsing
  defp process_args(args) do
    # Parse command line arguments using OptionParser
    case OptionParser.parse(args,
           switches: [
             help: :boolean,      # --help flag (boolean)
             mode: :string,       # --mode option (string)
             timeout: :integer,   # --timeout option (integer)
             output: :string      # --output option (string)
           ],
           aliases: [
             h: :help,           # -h alias for --help
             m: :mode,           # -m alias for --mode
             t: :timeout,        # -t alias for --timeout
             o: :output          # -o alias for --output
           ]
         ) do
      # Pattern 1: Help flag is present
      {[help: true], _, _} ->
        # Show help message and exit
        show_help()

      # Pattern 2: No files/directories specified
      {_, [], _} ->
        # Print error and show help
        IO.puts("Error: You need to specify a file or directory")
        show_help()

      # Pattern 3: Valid arguments with files/directories
      {opts, files, _} when is_list(files) and length(files) > 0 ->
        # Convert options list to map for easier access
        opts_map =
          case opts do
            [] -> %{}                    # Empty options → empty map
            _ -> Enum.into(opts, %{})    # Convert list of tuples to map
          end

        # Build configuration with defaults for missing values
        config = %{
          mode: Map.get(opts_map, :mode, "parallel"),        # Default: "parallel"
          timeout: Map.get(opts_map, :timeout, 5000),        # Default: 5000ms
          output_dir: Map.get(opts_map, :output, "output")   # Default: "output"
        }

        # Start processing the files with the configuration
        process_files(files, config)

      # Pattern 4: Invalid arguments (catch-all)
      _ ->
        IO.puts("Error in options")
        show_help()
    end
  end

  # Determines whether to process a single file or directory.
  #
  # Examines the first file path to decide processing strategy.
  #
  # ## Parameters
  #   - `files`: List of file paths (only first is used)
  #   - `config`: Configuration map with processing options
  #
  # ## Communication
  #   - Calls: `process_directory/2`, `process_single_file/2`
  #   - Uses: `File.dir?/1` to check path type
  defp process_files(files, config) do
    # Print processing header
    IO.puts("File Processor")
    IO.puts("Mode: #{config.mode}")
    IO.puts("")

    # Get the first file path from the list
    path = hd(files)

    # Check if path is a directory
    if File.dir?(path) do
      # Process as directory
      process_directory(path, config)
    else
      # Process as single file
      process_single_file(path, config)
    end
  end

  # Processes all files in a directory based on the selected mode.
  #
  # Supports sequential, parallel, and benchmark processing modes.
  # Handles directory validation and error cases.
  #
  # ## Parameters
  #   - `dir`: Directory path to process
  #   - `config`: Configuration map with mode, timeout, etc.
  #
  # ## Communication
  #   - Calls: `ProcesadorArchivos.process_files_with_config/2`,
  #            `ProcesadorArchivos.process_parallel/1`,
  #            `ProcesadorArchivos.benchmark/2`
  #   - Uses: `File.ls/1` to list directory contents
  defp process_directory(dir, config) do
    # Validate directory exists
    unless File.dir?(dir) do
      IO.puts("Error: Directory doesn't exist")
      System.halt(1)  # Exit with error code
    end

    # List directory contents
    case File.ls(dir) do
      # Success: files found
      {:ok, archivos} ->
        IO.puts("Found #{length(archivos)} files in '#{dir}'")

        # Create full paths for all files
        full_paths = Enum.map(archivos, &Path.join(dir, &1))

        # Dispatch based on processing mode
        case config.mode do
          "sequential" ->
            IO.puts("Sequential mode...")

            # Call sequential processor with configuration
            result = ProcesadorArchivos.process_files_with_config(dir, %{
              timeout: config.timeout,
              generate_report: true,  # Force report generation
              verbose: false
            })

            # Handle result
            case result do
              {:ok, _} -> IO.puts("Sequential processing completed")
              {:error, reason} -> IO.puts("Error: #{reason}")
            end

          "parallel" ->
            IO.puts("Parallel mode...")

            # Call parallel processor (auto-generates report)
            result = ProcesadorArchivos.process_parallel(full_paths)

            # Display results
            IO.puts("Completed in #{result.total_time}ms")
            IO.puts("Results: #{result.successes} successful, #{result.errors} errors")

          "benchmark" ->
            # Run benchmark mode with default configuration
            ProcesadorArchivos.benchmark(dir, %{})

          # Unknown mode - default to parallel
          _ ->
            IO.puts("Unknown mode, using parallel")
            result = ProcesadorArchivos.process_parallel(full_paths)

            IO.puts("Completed in #{result.total_time}ms")
            IO.puts("Results: #{result.successes} successful, #{result.errors} errors")
        end

      # Error: cannot read directory
      {:error, razon} ->
        IO.puts("Error reading directory: #{razon}")
        System.halt(1)  # Exit with error code
    end
  end

  # Processes a single file with error handling.
  #
  # Validates file existence and displays processing results.
  #
  # ## Parameters
  #   - `file`: Path to the file to process
  #   - `config`: Configuration map (not used in single file mode)
  #
  # ## Communication
  #   - Calls: `ProcesadorArchivos.procesar_con_manejo_errores/2`
  #   - Uses: `File.exists?/1` to validate file
  defp process_single_file(file, config) do
    # Validate file exists
    unless File.exists?(file) do
      IO.puts("Error: File doesn't exist")
      System.halt(1)  # Exit with error code
    end

    # Show file being processed
    IO.puts("Processing: #{Path.basename(file)}")

    # Process file with error handling
    resultado = ProcesadorArchivos.procesar_con_manejo_errores(file, config)

    # Display results based on outcome
    case resultado do
      # Error case
      %{estado: :error, error: error} ->
        IO.puts("Error: #{error}")

      # Success case with statistics
      %{
        estado: estado,
        lineas_procesadas: procesadas,
        lineas_con_error: errores
      } ->
        IO.puts("Status: #{estado}")
        IO.puts("Processed: #{procesadas} lines")
        if errores > 0, do: IO.puts("Errors: #{errores} lines")

      # Unexpected result format
      _ ->
        IO.puts("Result: #{inspect(resultado, limit: 3)}")
    end
  end

  # Displays help message with usage instructions.
  #
  # Shows available options, aliases, and examples.
  #
  # ## Communication
  #   - Called by: `process_args/1` when help is requested or errors occur
  defp show_help do
    IO.puts("""
    USAGE: ./procesador_archivos [OPTIONS] FILE|DIRECTORY

    Options:
      -h, --help      Shows this help
      -m, --mode      Mode: sequential, parallel, benchmark
      -t, --timeout   Timeout in milliseconds
      -o, --output    Output directory

    Examples:
      ./procesador_archivos data/valid
      ./procesador_archivos --mode sequential data/valid
      ./procesador_archivos --mode benchmark data/valid
    """)
  end
end
