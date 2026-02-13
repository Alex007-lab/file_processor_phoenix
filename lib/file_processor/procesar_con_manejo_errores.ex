# lib/procesar_con_manejo_errores.ex - VERSIÓN CORREGIDA

# Defines the module specialized in processing with robust error handling
# This module is specifically designed to handle corrupt or malformed files
defmodule ProcesadorArchivos.ProcesarConManejoErrores do
  @moduledoc """
  Module for processing with detailed error handling.

  This module provides advanced error handling for processing files that
  may be corrupted, malformed, or contain invalid data. It processes files
  line by line, detecting and reporting errors while continuing to process
  valid data.

  ## Features

  - Line-by-line processing with detailed error reporting
  - Graceful handling of malformed data
  - Support for CSV, JSON, and LOG file formats
  - Statistical reporting of valid vs invalid data
  - Safe parsing functions that don't crash on invalid input

  ## Functions

  ### Public Functions
  - `procesar/2` - Main entry point for processing files with error handling

  ### Private Functions
  #### CSV Processing
  - `procesar_csv_con_errores/1` - Main CSV error handler
  - `procesar_lineas_csv/4` - Recursive CSV line processor
  - `validar_linea_csv/1` - Validates individual CSV lines
  - Various field validators: `validar_fecha/2`, `validar_producto/2`, etc.

  #### JSON Processing
  - `procesar_json_con_errores/1` - Main JSON error handler

  #### LOG Processing
  - `procesar_log_con_errores/1` - Main LOG error handler
  - `es_linea_log_valida?/1` - Validates log line format
  - `extraer_nivel_log/1` - Extracts log level from line

  #### Utility Functions
  - `safe_parse_float/1` - Safe float parsing (no exceptions)
  - `safe_parse_int/1` - Safe integer parsing (no exceptions)
  """

  @doc """
  Main public function that acts as entry point for error handling.

  Dispatches to appropriate file processor based on file extension.

  ## Parameters
    - `file_path`: Path of file to process
    - `_config`: Optional configuration map (currently unused, kept for API compatibility)

  ## Returns
    - Map with detailed processing results including:
      - `:estado` - Processing state (:completo, :parcial, :error)
      - `:lineas_procesadas` - Number of successfully processed lines (for CSV/LOG)
      - `:lineas_con_error` - Number of lines with errors (for CSV/LOG)
      - `:errores` - List of error tuples {line_number, error_message, line_content}
      - `:archivo` - Base name of processed file
      - `:tipo_archivo` - File type (:csv, :json, :log)
      - `:detalles` - Map with additional processing details
    - `{:error, reason}` on complete processing failure

  ## Communication
    - Uses: `Path.extname/1` to determine file type
    - Calls type-specific processors: `procesar_csv_con_errores/1`,
      `procesar_json_con_errores/1`, `procesar_log_con_errores/1`

  ## Example
      iex> ProcesarConManejoErrores.procesar("data/corrupt.csv")
      %{
        estado: :parcial,
        lineas_procesadas: 85,
        lineas_con_error: 15,
        archivo: "corrupt.csv",
        tipo_archivo: :csv,
        detalles: %{...}
      }
  """
  def procesar(file_path, _config \\ %{}) do
    # Determines file type based on its extension
    case Path.extname(file_path) do
      # Processes CSV files
      ".csv" -> procesar_csv_con_errores(file_path)
      # Processes JSON files
      ".json" -> procesar_json_con_errores(file_path)
      # Processes LOG files
      ".log" -> procesar_log_con_errores(file_path)
      # Unknown format
      _ -> {:error, "Unsupported format: #{Path.extname(file_path)}"}
    end
  end

  # ============ CSV SECTION ============

  # Private function to process CSV files with detailed error handling
  #
  # ## Parameters
  #   - `file_path`: Path to CSV file
  #
  # ## Returns
  #   - Map with CSV processing results (see `procesar/2` return format)
  #   - `{:error, reason}` on complete failure
  #
  # ## Processing Logic
  #   1. Verifies file existence
  #   2. Reads entire file
  #   3. Validates minimum structure (header + at least one data line)
  #   4. Processes each data line individually
  #   5. Collects statistics and error details
  #
  # ## Communication
  #   - Uses: `File.exists?/1`, `File.read!/1`, `String.split/2`, `Path.basename/1`
  #   - Calls: `procesar_lineas_csv/4`, `obtener_detalles_csv/3`
  #   - Handles exceptions with `rescue`
  defp procesar_csv_con_errores(file_path) do
    # First verifies the file exists
    if File.exists?(file_path) do
      try do
        # Reads all file content (can throw exception!)
        # File.read!/1 reads entire file as binary string
        # ! indicates it raises exception on error instead of returning {:error, ...}
        content = File.read!(file_path)
        # Splits by lines (\n is newline character)
        # Creates list of strings, each representing one line
        lines = String.split(content, "\n")

        # Verifies it has at least 2 lines (header + at least 1 data line)
        if length(lines) < 2 do
          {:error, "Empty file or no data after header"}
        else
          # Pattern matching: separates header from data
          # _header: ignores first line (header) - not used for validation
          # data_lines: list with remaining lines (data to process)
          [_header | data_lines] = lines

          # Processes data lines recursively
          # Parameters:
          #   data_lines: List of data lines to process
          #   2: initial line number (first data line, after header)
          #   0: counter of successfully processed lines
          #   []: accumulator list for errors (empty at start)
          {procesadas, errores} = procesar_lineas_csv(data_lines, 2, 0, [])

          # Returns map with structured results
          %{
            estado: if(length(errores) > 0, do: :parcial, else: :completo),
            lineas_procesadas: procesadas,
            lineas_con_error: length(errores),
            # Reverse to maintain original order (errors were added to front)
            errores: Enum.reverse(errores),
            total_lineas: length(data_lines),
            # Only the name, not full path
            archivo: Path.basename(file_path),
            tipo_archivo: :csv,
            detalles:
              obtener_detalles_csv(
                procesadas,
                length(errores),
                length(data_lines)
              )
          }
        end
      rescue
        # Exception handling during reading/processing
        error ->
          # USAR Exception.message/1 en lugar de error.message
          # Exception.message/1 safely extracts error message from any exception
          error_message = Exception.message(error)
          {:error, "Error processing CSV: #{error_message}"}
      end
    else
      # File doesn't exist
      {:error, "File not found: #{file_path}"}
    end
  end

  # Generates detailed statistics for CSV processing
  #
  # ## Parameters
  #   - `procesadas`: Number of successfully processed lines
  #   - `errores`: Number of lines with errors
  #   - `total`: Total number of data lines
  #
  # ## Returns
  #   - Map with statistical details:
  #     - `:lineas_validas`: Count of valid lines
  #     - `:lineas_invalidas`: Count of invalid lines
  #     - `:total_lineas`: Total lines processed
  #     - `:porcentaje_exito`: Success percentage (rounded to 2 decimals)
  #     - `:porcentaje_error`: Error percentage (rounded to 2 decimals)
  #     - `:recomendacion`: Processing recommendation based on results
  #
  # ## Communication
  #   - Called by: `procesar_csv_con_errores/1`
  #   - Uses: `Float.round/2` for percentage formatting
  defp obtener_detalles_csv(procesadas, errores, total) do
    %{
      lineas_validas: procesadas,
      lineas_invalidas: errores,
      total_lineas: total,
      porcentaje_exito:
        if(total > 0, do: Float.round(procesadas / total * 100, 2), else: 0.0),
      porcentaje_error:
        if(total > 0, do: Float.round(errores / total * 100, 2), else: 0.0),
      recomendacion:
        if(errores > 0,
          do: "Revisar formato de datos en líneas con error",
          else: "Archivo válido"
        )
    }
  end

  # Recursive function to process CSV lines - BASE CASE
  # When no lines remain to process
  #
  # ## Parameters
  #   - `[]`: Empty list (no more lines)
  #   - `_`: Current line number (ignored in base case)
  #   - `procesadas`: Total successfully processed lines
  #   - `errores`: List of accumulated errors
  #
  # ## Returns
  #   - Tuple {procesadas, errores} with final counts
  defp procesar_lineas_csv([], _, procesadas, errores),
    do: {procesadas, errores}

  # Recursive function to process CSV lines - RECURSIVE CASE
  # Processes current line and calls recursively for the rest
  #
  # ## Parameters
  #   - `[line | rest]`: List with current line and remaining lines
  #   - `num_linea`: Current line number (starting from 2 for data lines)
  #   - `procesadas`: Count of successfully processed lines so far
  #   - `errores`: List of errors collected so far
  #
  # ## Returns
  #   - Updated tuple {procesadas, errores} after processing current line
  #
  # ## Communication
  #   - Calls: `validar_linea_csv/1` to validate each line
  #   - Recursively calls itself with updated parameters
  defp procesar_lineas_csv([line | rest], num_linea, procesadas, errores) do
    # Conditional to handle different line cases
    cond do
      # Case 1: Empty line (only spaces/tabs)
      # String.trim/1 removes leading/trailing whitespace
      String.trim(line) == "" ->
        # Ignores empty line, continues with next line
        # Increments line number but doesn't count as processed or error
        procesar_lineas_csv(rest, num_linea + 1, procesadas, errores)

      # Case 2: Line with content
      true ->
        # Validates current line
        case validar_linea_csv(line) do
          # Valid line - increment success count
          :ok ->
            procesar_lineas_csv(rest, num_linea + 1, procesadas + 1, errores)

          # Line with error - add to error list
          {:error, mensaje} ->
            # Builds error tuple: {line_number, error_message, line_content}
            # Limits line content to 50 characters for readability
            contenido_reducido =
              String.slice(line, 0..50) <>
                if String.length(line) > 50, do: "...", else: ""

            nuevo_error = {num_linea, mensaje, contenido_reducido}
            # Adds error to list (at beginning for efficiency - building list backwards)
            # Will be reversed at the end to restore original order
            procesar_lineas_csv(rest, num_linea + 1, procesadas, [
              nuevo_error | errores
            ])
        end
    end
  end

  # Validates an individual CSV line
  #
  # ## Parameters
  #   - `line`: String containing a CSV data line
  #
  # ## Returns
  #   - `:ok` if line is valid
  #   - `{:error, message}` if line has validation errors
  #
  # ## Validation Steps
  #   1. Split line into fields by comma
  #   2. Verify exactly 6 fields
  #   3. Validate each field individually
  #   4. Collect all validation errors
  #
  # ## Communication
  #   - Calls field-specific validators: `validar_fecha/2`, `validar_producto/2`, etc.
  #   - Called by: `procesar_lineas_csv/4`
  defp validar_linea_csv(line) do
    # Splits line by commas to get fields
    campos = String.split(line, ",")

    # Verifies it has exactly 6 fields (expected format: date,product,category,price,quantity,discount)
    if length(campos) != 6 do
      {:error, "Incomplete line (#{length(campos)} fields instead of 6)"}
    else
      # Pattern matching to extract specific fields
      # _ prefix indicates we're not interested in that value (just extracting)
      [fecha, producto, categoria, precio_str, cantidad_str, descuento_str] =
        campos

      # Initializes empty error list
      errores = []
      # Chain validators, each adding errors if validation fails
      errores = validar_fecha(fecha, errores)
      errores = validar_producto(producto, errores)
      errores = validar_categoria(categoria, errores)
      errores = validar_precio(precio_str, errores)
      errores = validar_cantidad(cantidad_str, errores)
      errores = validar_descuento(descuento_str, errores)

      # If no errors, returns :ok, otherwise returns error message
      if Enum.empty?(errores) do
        :ok
      else
        # Joins multiple errors with comma for single error message
        {:error, Enum.join(errores, ", ")}
      end
    end
  end

  # Validates date field
  #
  # ## Parameters
  #   - `fecha`: Date string to validate
  #   - `errores`: Current list of errors
  #
  # ## Returns
  #   - Updated error list (with date error added if invalid)
  #
  # ## Validation Rules
  #   - Cannot be empty string
  #   - Must be at least 8 characters (basic length check)
  #
  # ## Note: This is a basic validation. In production, you might want to
  # ## parse the date and validate format (YYYY-MM-DD)
  defp validar_fecha(fecha, errores) do
    fecha_trim = String.trim(fecha)

    cond do
      fecha_trim == "" ->
        ["Empty date" | errores]

      String.length(fecha_trim) < 8 ->
        ["Invalid date format (too short)" | errores]

      true ->
        errores
    end
  end

  # Validates product field
  #
  # ## Parameters
  #   - `producto`: Product name string
  #   - `errores`: Current list of errors
  #
  # ## Returns
  #   - Updated error list
  #
  # ## Validation Rules
  #   - Cannot be empty string
  defp validar_producto(producto, errores) do
    producto_trim = String.trim(producto)

    if producto_trim == "" do
      ["Empty product name" | errores]
    else
      errores
    end
  end

  # Validates category field
  #
  # ## Parameters
  #   - `categoria`: Category string
  #   - `errores`: Current list of errors
  #
  # ## Returns
  #   - Updated error list
  #
  # ## Validation Rules
  #   - Cannot be empty string
  defp validar_categoria(categoria, errores) do
    categoria_trim = String.trim(categoria)

    if categoria_trim == "" do
      ["Empty category" | errores]
    else
      errores
    end
  end

  # Functions that return updated error list
  # Validates price field: must be positive float number
  #
  # ## Parameters
  #   - `precio_str`: Price as string
  #   - `errores`: Current list of errors
  #
  # ## Returns
  #   - Updated error list
  #
  # ## Validation Rules
  #   - Must be a valid float number
  #   - Must be greater than 0
  #
  # ## Communication
  #   - Calls: `safe_parse_float/1` for safe parsing
  defp validar_precio(precio_str, errores) do
    case safe_parse_float(precio_str) do
      # Valid and positive price
      {:ok, precio} when precio > 0 ->
        # Doesn't add error
        errores

      # Valid but not positive price (0 or negative)
      {:ok, precio} when precio <= 0 ->
        ["Price must be positive (found: #{precio})" | errores]

      # Price is not a valid number
      {:error, _} ->
        precio_trim = String.trim(precio_str)

        if precio_trim == "" do
          ["Empty price" | errores]
        else
          ["Invalid price: '#{precio_trim}'" | errores]
        end
    end
  end

  # Validates quantity field: must be positive integer
  #
  # ## Parameters
  #   - `cantidad_str`: Quantity as string
  #   - `errores`: Current list of errors
  #
  # ## Returns
  #   - Updated error list
  #
  # ## Validation Rules
  #   - Must be a valid integer
  #   - Must be greater than 0
  #
  # ## Communication
  #   - Calls: `safe_parse_int/1` for safe parsing
  defp validar_cantidad(cantidad_str, errores) do
    case safe_parse_int(cantidad_str) do
      # Valid and positive quantity
      {:ok, cantidad} when cantidad > 0 ->
        errores

      # Valid but not positive quantity (0 or negative)
      {:ok, cantidad} when cantidad <= 0 ->
        ["Quantity must be positive (found: #{cantidad})" | errores]

      # Quantity is not a valid number
      {:error, _} ->
        cantidad_trim = String.trim(cantidad_str)

        if cantidad_trim == "" do
          ["Empty quantity" | errores]
        else
          ["Invalid quantity: '#{cantidad_trim}'" | errores]
        end
    end
  end

  # Validates discount field: must be percentage between 0 and 100
  #
  # ## Parameters
  #   - `descuento_str`: Discount as string
  #   - `errores`: Current list of errors
  #
  # ## Returns
  #   - Updated error list
  #
  # ## Validation Rules
  #   - Must be a valid float number
  #   - Must be between 0 and 100 (inclusive)
  #
  # ## Communication
  #   - Calls: `safe_parse_float/1` for safe parsing
  defp validar_descuento(descuento_str, errores) do
    case safe_parse_float(descuento_str) do
      # Valid discount and within allowed range (0-100)
      {:ok, descuento} when descuento >= 0 and descuento <= 100 ->
        errores

      # Negative discount
      {:ok, descuento} when descuento < 0 ->
        ["Negative discount: #{descuento}%" | errores]

      # Discount greater than 100%
      {:ok, descuento} when descuento > 100 ->
        ["Discount too high: #{descuento}% (max 100%)" | errores]

      # Discount is not a valid number
      {:error, _} ->
        descuento_trim = String.trim(descuento_str)

        if descuento_trim == "" do
          ["Empty discount" | errores]
        else
          ["Invalid discount: '#{descuento_trim}'" | errores]
        end
    end
  end

  # SAFE parsing functions (don't throw exceptions)
  # Safely parses string to float
  #
  # ## Parameters
  #   - `str`: String to parse as float
  #
  # ## Returns
  #   - `{:ok, float_value}` on successful parsing
  #   - `{:error, reason}` on parsing failure
  #
  # ## Features
  #   - Handles strings with trailing non-numeric characters
  #   - Doesn't raise exceptions on invalid input
  #   - Trims whitespace before parsing
  #
  # ## Communication
  #   - Used by: `validar_precio/2`, `validar_descuento/2`
  defp safe_parse_float(str) do
    try do
      # Float.parse returns {value, remainder} or :error
      case Float.parse(String.trim(str)) do
        # String completely parsed (no remainder)
        {num, ""} -> {:ok, num}
        # String partially parsed (we accept this - e.g., "19.99USD")
        {num, _rest} -> {:ok, num}
        # Not a float number
        :error -> {:error, :not_a_number}
      end
    rescue
      # Any exception during parsing (shouldn't happen with Float.parse but safe)
      _ -> {:error, :parse_error}
    end
  end

  # Safely parses string to integer
  #
  # ## Parameters
  #   - `str`: String to parse as integer
  #
  # ## Returns
  #   - `{:ok, int_value}` on successful parsing
  #   - `{:error, reason}` on parsing failure
  #
  # ## Features
  #   - Handles strings with trailing non-numeric characters
  #   - Doesn't raise exceptions on invalid input
  #   - Trims whitespace before parsing
  #
  # ## Communication
  #   - Used by: `validar_cantidad/2`
  defp safe_parse_int(str) do
    try do
      # Integer.parse returns {value, remainder} or :error
      case Integer.parse(String.trim(str)) do
        # String completely parsed (no remainder)
        {num, ""} -> {:ok, num}
        # String partially parsed (we accept this - e.g., "10pcs")
        {num, _rest} -> {:ok, num}
        # Not an integer number
        :error -> {:error, :not_a_number}
      end
    rescue
      # Any exception during parsing
      _ -> {:error, :parse_error}
    end
  end

  # ============ JSON SECTION ============

  # Private function to process JSON files with error handling
  #
  # ## Parameters
  #   - `file_path`: Path to JSON file
  #
  # ## Returns
  #   - Map with JSON processing results (see `procesar/2` return format)
  #   - `{:error, reason}` on complete failure (file not found)
  #
  # ## Processing Logic
  #   1. Verifies file existence
  #   2. Reads and parses JSON using Jason.decode!/1
  #   3. Extracts user and session statistics
  #   4. Handles JSON parsing errors gracefully
  #
  # ## Communication
  #   - Uses: `File.exists?/1`, `File.read!/1`, `Jason.decode!/1`, `Map.get/3`
  #   - Handles `Jason.DecodeError` and other exceptions
  defp procesar_json_con_errores(file_path) do
    if File.exists?(file_path) do
      try do
        # Reads and parses JSON in one step
        content = File.read!(file_path)
        parsed = Jason.decode!(content)  # Can throw Jason.DecodeError!

        # Extract statistics from JSON
        # Map.get/3 with default empty list [] if key doesn't exist
        users = Map.get(parsed, "usuarios", [])
        sessions = Map.get(parsed, "sesiones", [])

        # Count active users (those with "activo": true)
        active_users = Enum.count(users, &Map.get(&1, "activo", false))

        # If we reach here, JSON is valid
        %{
          estado: :completo,
          archivo: Path.basename(file_path),
          tipo_archivo: :json,
          detalles: %{
            total_usuarios: length(users),
            usuarios_activos: active_users,
            total_sesiones: length(sessions),
            estructura_valida: true,
            campos_presentes: Map.keys(parsed),
            recomendacion: "JSON válido y bien formado"
          }
        }
      rescue
        # Specific JSON decoding error
        error in Jason.DecodeError ->
          # USAR Exception.message/1 para obtener el mensaje
          error_message = Exception.message(error)

          # Intentar obtener información de la posición usando inspect
          # Jason.DecodeError no expone públicamente los campos .position o .data
          error_details = inspect(error)

          # Extraer información útil del mensaje de error
          position_info =
            if String.contains?(error_message, "position") do
              # Intentar extraer posición del mensaje
              case Regex.run(~r/position\s*(\d+)/i, error_message) do
                [_, pos] -> "position #{pos}"
                _ -> "unknown"
              end
            else
              "unknown"
            end

          %{
            estado: :error,
            archivo: Path.basename(file_path),
            tipo_archivo: :json,
            error: "Malformed JSON",
            detalles: %{
              mensaje_error: error_message,
              posicion: position_info,
              detalles_completos: String.slice(error_details, 0..200), # Limitar longitud
              tipo_error: "Jason.DecodeError",
              recomendacion: "Verificar sintaxis JSON, comillas y llaves"
            }
          }
        # Any other error
        error ->
          # USAR Exception.message/1 para obtener el mensaje
          error_message = Exception.message(error)

          %{
            estado: :error,
            archivo: Path.basename(file_path),
            tipo_archivo: :json,
            error: "Error processing JSON",
            detalles: %{
              mensaje_error: error_message,
              tipo_error: inspect(error.__struct__),
              sugerencia: "Para más detalles, verifique logs del sistema",
              recomendacion: "Verificar permisos y formato del archivo"
            }
          }
      end
    else
      {:error, "File not found: #{file_path}"}
    end
  end

  # ============ LOG SECTION ============

  # Private function to process LOG files with error handling
  #
  # ## Parameters
  #   - `file_path`: Path to LOG file
  #
  # ## Returns
  #   - Map with LOG processing results (see `procesar/2` return format)
  #   - `{:error, reason}` on complete failure
  #
  # ## Processing Logic
  #   1. Verifies file existence
  #   2. Reads and splits into lines
  #   3. Separates valid from invalid log lines
  #   4. Counts log levels for valid lines
  #   5. Creates error details for invalid lines
  #   6. Calculates statistics
  #
  # ## Communication
  #   - Uses: `File.exists?/1`, `File.read!/1`, `String.split/3`, `Enum.split_with/2`
  #   - Calls: `es_linea_log_valida?/1`, `extraer_nivel_log/1`
  defp procesar_log_con_errores(file_path) do
    if File.exists?(file_path) do
      try do
        # Reads and splits lines, removing empty lines (trim: true)
        # File.read!/1 reads entire file
        # String.split/3 with trim: true removes empty strings from result
        lines = File.read!(file_path) |> String.split("\n", trim: true)

        if length(lines) == 0 do
          %{
            estado: :error,
            archivo: Path.basename(file_path),
            tipo_archivo: :log,
            error: "Empty file",
            detalles: %{
              total_lineas: 0,
              recomendacion: "El archivo está vacío"
            }
          }
        else
          # Separates valid lines from invalid ones
          # Enum.split_with/2 splits list based on predicate function
          {validas, invalidas} = Enum.split_with(lines, &es_linea_log_valida?/1)

          # Count log levels for valid lines using Enum.reduce
          # Start with map of counters initialized to 0
          niveles =
            Enum.reduce(
              validas,
              %{debug: 0, info: 0, warn: 0, error: 0, fatal: 0},
              fn line, acc ->
                nivel = extraer_nivel_log(line)
                # Map.update updates value for key, with default 0 if key doesn't exist
                Map.update(acc, nivel, 1, &(&1 + 1))
              end
            )

          # Processes invalid lines to create error tuples
          # Enum.with_index/2 adds index starting at 1
          errores =
            Enum.with_index(invalidas, 1)
            |> Enum.map(fn {linea, idx} ->
              # Limits message to 30 characters to avoid very long lines
              {idx, "Invalid format: #{String.slice(linea, 0..30)}...",
               String.slice(linea, 0..50)}
            end)

          %{
            estado: if(length(invalidas) > 0, do: :parcial, else: :completo),
            lineas_procesadas: length(validas),
            lineas_con_error: length(invalidas),
            errores: errores,
            archivo: Path.basename(file_path),
            tipo_archivo: :log,
            detalles: %{
              total_lineas: length(lines),
              porcentaje_valido:
                Float.round(length(validas) / length(lines) * 100, 2),
              porcentaje_invalido:
                Float.round(length(invalidas) / length(lines) * 100, 2),
              distribucion_niveles: niveles,
              recomendacion:
                if(length(invalidas) > 0,
                  do: "Revisar formato de líneas inválidas",
                  else: "Archivo de log válido"
                )
            }
          }
        end
      rescue
        # General error handling
        error ->
          # USAR Exception.message/1 para obtener el mensaje
          error_message = Exception.message(error)
          {:error, "Error processing LOG: #{error_message}"}
      end
    else
      {:error, "File not found: #{file_path}"}
    end
  end

  # Determines if a log line has valid format
  #
  # ## Parameters
  #   - `line`: Log line string to validate
  #
  # ## Returns
  #   - `true` if line matches log format
  #   - `false` otherwise
  #
  # ## Format Pattern
  #   Expected: "YYYY-MM-DD HH:MM:SS [LEVEL] message"
  #   Example: "2023-10-15 14:30:45 [ERROR] Database connection failed"
  #
  # ## Regex Explanation
  #   ~r/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(DEBUG|INFO|WARN|ERROR|FATAL)\]/i
  #   ^ : Start of string
  #   \d{4} : Exactly 4 digits (year)
  #   - : Literal hyphen
  #   \d{2} : Exactly 2 digits (month)
  #   - : Literal hyphen
  #   \d{2} : Exactly 2 digits (day)
  #   (space) : Literal space
  #   \d{2} : Exactly 2 digits (hour)
  #   : : Literal colon
  #   \d{2} : Exactly 2 digits (minute)
  #   : : Literal colon
  #   \d{2} : Exactly 2 digits (second)
  #   (space) : Literal space
  #   \[ : Literal '[' (escaped)
  #   (DEBUG|INFO|WARN|ERROR|FATAL) : Capture group with log levels
  #   \] : Literal ']' (escaped)
  #   /i : Case-insensitive flag
  defp es_linea_log_valida?(line) do
    # Simpler and more tolerant regular expression pattern
    # Looks for: date time [LEVEL] ... (case-insensitive)
    Regex.match?(
      ~r/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(DEBUG|INFO|WARN|ERROR|FATAL)\]/i,
      line
    )
  end

  # Extracts log level from valid line
  #
  # ## Parameters
  #   - `line`: Valid log line string
  #
  # ## Returns
  #   - Atom representing log level (:debug, :info, :warn, :error, :fatal)
  #   - `:unknown` if no level found (shouldn't happen with valid lines)
  #
  # ## Communication
  #   - Called by: `procesar_log_con_errores/1` during log level counting
  defp extraer_nivel_log(line) do
    case Regex.run(~r/\[(DEBUG|INFO|WARN|ERROR|FATAL)\]/i, line) do
      [_, nivel] -> String.downcase(nivel) |> String.to_atom()
      _ -> :unknown
    end
  end
end
