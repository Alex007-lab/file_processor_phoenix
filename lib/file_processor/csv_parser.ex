# Define módulo para parsear archivos CSV
defmodule CsvParser do
  # Documentación del módulo que aparecerá en documentación generada
  @moduledoc """
  CSV parser for sales data.

  This module provides functionality to parse CSV files containing sales data.
  It validates, processes, and calculates metrics from CSV records.

  Expected CSV format: date,product,category,price,quantity,discount

  ## Functions

  ### Public Functions
  - `process/1` - Main function to process CSV files

  ### Private Functions
  - `parse_line/1` - Parses individual CSV lines
  - `valid_record?/1` - Validates record data
  - `parse_float/1` - Converts string to float
  - `parse_int/1` - Converts string to integer
  - `calculate_total/1` - Calculates total sales
  - `count_unique/1` - Counts unique products
  """

  @doc """
  Main function to process CSV files.

  Reads a CSV file, parses its content, validates records, and calculates metrics.

  ## Parameters
    - `file_path`: String path to the CSV file

  ## Returns
    - `{:ok, metrics}` on success, where metrics is a map containing:
      - `total_sales`: Total sales amount (float rounded to 2 decimals)
      - `unique_products`: Count of unique product names
      - `valid_records`: Number of valid records processed
      - `file_name`: Base name of the processed file
    - `{:error, reason}` on failure, where reason describes the error

  ## Communication
    - Uses: `File.exists?/1`, `File.read!/1`, `String.split/2`, `Path.basename/1`
    - Calls private functions: `parse_line/1`, `valid_record?/1`,
      `calculate_total/1`, `count_unique/1`

  ## Examples
      iex> CsvParser.process("sales.csv")
      {:ok, %{total_sales: 1520.75, unique_products: 5, valid_records: 100, file_name: "sales.csv"}}

      iex> CsvParser.process("nonexistent.csv")
      {:error, "File not found: nonexistent.csv"}
  """
  def process(file_path) do
    # Verifica si el archivo existe usando File.exists?/1
    if File.exists?(file_path) do
      # Bloque try para capturar errores durante el procesamiento
      try do
        # Lee todo el archivo y lo divide por líneas
        # File.read!/1 lee el contenido completo (¡lanza excepción si falla!)
        # String.split/2 divide el string por el separador "\n" (salto de línea)
        lines = File.read!(file_path) |> String.split("\n")

        # Separa encabezado (primera línea) de datos usando pattern matching
        # La variable _header contiene la primera línea pero no la usamos (por eso el _)
        # data_lines contiene el resto de las líneas (tail de la lista)
        [_header | data_lines] = lines

        # Procesa líneas de datos usando pipeline de operaciones
        valid_records =
          data_lines
          # Filtra líneas vacías usando Enum.filter/2
          # &(&1 != "") es una función anónima que verifica si el elemento no es string vacío
          |> Enum.filter(&(&1 != ""))
          # Parsea cada línea llamando a la función privada parse_line/1
          # Enum.map/2 aplica parse_line a cada elemento de la lista
          |> Enum.map(&parse_line/1)
          # Filtra solo registros válidos usando valid_record?/1
          |> Enum.filter(&valid_record?/1)

        # Calcula métricas (mínimo 3 requeridas) y las organiza en un mapa
        metrics = %{
          # Ventas totales: llama a calculate_total/1 con los registros válidos
          total_sales: calculate_total(valid_records),
          # Productos únicos: cuenta productos distintos
          unique_products: count_unique(valid_records),
          # Registros válidos: usa length/1 para contar elementos de la lista
          valid_records: length(valid_records),
          # Nombre del archivo: extrae solo el nombre sin la ruta
          file_name: Path.basename(file_path)
        }

        # Retorna tupla de éxito con métricas
        {:ok, metrics}

        # Manejo de errores durante el parsing usando rescue
      rescue
        # Captura cualquier error y retorna tupla de error con descripción
        error -> {:error, "CSV parsing error: #{inspect(error)}"}
      end
    else
      # Si el archivo no existe, retorna tupla de error
      {:error, "File not found: #{file_path}"}
    end
  end

  # Parsea una línea individual del CSV
  # Es privada (defp) porque solo se usa dentro del módulo
  # Formato esperado: date,product,category,price,quantity,discount
  #
  # ## Parameters
  #   - `line`: String containing a CSV line with 6 comma-separated values
  #
  # ## Returns
  #   - Map with parsed data if line has 6 fields:
  #     %{date: date_str, product: product_str, category: category_str,
  #       price: float, quantity: integer, discount: float}
  #   - `nil` if line doesn't have exactly 6 fields
  #
  # ## Communication
  #   - Calls: `String.split/2`, `parse_float/1`, `parse_int/1`
  #   - Called by: `process/1` via Enum.map
  defp parse_line(line) do
    # Divide la línea por comas usando String.split/2
    case String.split(line, ",") do
      # Pattern matching: si tiene exactamente 6 campos, extrae cada uno
      [date, product, category, price_str, quantity_str, discount_str] ->
        # Crea mapa con los datos parseados
        %{
          # Fecha como string (no se parsea a fecha real)
          date: date,
          # Producto como string
          product: product,
          # Categoría como string
          category: category,
          # Precio: convierte string a número usando parse_float/1
          price: parse_float(price_str),
          # Cantidad: convierte string a entero usando parse_int/1
          quantity: parse_int(quantity_str),
          # Descuento: convierte string a número (porcentaje)
          discount: parse_float(discount_str)
        }

      # Si no tiene 6 campos (cualquier otro caso), retorna nil
      _ ->
        nil
    end
  end

  # Verifica si un registro es válido
  # Primera cláusula: si el registro es nil, retorna false
  #
  # ## Parameters
  #   - `nil`: Special case for invalid parse_line result
  #   - `record`: Map containing parsed CSV data
  #
  # ## Returns
  #   - `true` if record meets all validation criteria
  #   - `false` if record is nil or fails validation
  #
  # ## Validation Criteria
  #   1. Price must be a positive number
  #   2. Quantity must be a positive integer
  #   3. Discount must be a number between 0 and 100 (inclusive)
  #
  # ## Communication
  #   - Uses: `is_number/1`, comparison operators
  #   - Called by: `process/1` via Enum.filter
  defp valid_record?(nil), do: false

  # Segunda cláusula: cuando el registro no es nil
  defp valid_record?(record) do
    # Un registro es válido si cumple todas estas condiciones:
    # 1. El precio es número positivo (is_number/1 verifica tipo)
    # 2. La cantidad es número positivo
    # 3. El descuento está entre 0 y 100% (inclusive)
    # Usamos operadores lógicos "and" para combinar condiciones
    is_number(record.price) and record.price > 0 and
      is_number(record.quantity) and record.quantity > 0 and
      is_number(record.discount) and record.discount >= 0 and
      record.discount <= 100
  end

  # Convierte string a número decimal (float)
  #
  # ## Parameters
  #   - `string`: String to convert to float
  #
  # ## Returns
  #   - Float number if conversion succeeds
  #   - Atom `:error` if conversion fails
  #
  # ## Communication
  #   - Uses: `Float.parse/1` for conversion
  #   - Called by: `parse_line/1` for price and discount fields
  defp parse_float(string) do
    # Float.parse/1 intenta convertir string a float
    # Retorna tupla {número, resto} o :error si falla
    case Float.parse(string) do
      # Si se puede parsear, retorna solo el número (ignoramos el resto)
      {number, _} -> number
      # Si no se puede parsear, retorna átomo :error
      :error -> :error
    end
  end

  # Convierte string a número entero
  #
  # ## Parameters
  #   - `string`: String to convert to integer
  #
  # ## Returns
  #   - Integer number if conversion succeeds
  #   - Atom `:error` if conversion fails
  #
  # ## Communication
  #   - Uses: `Integer.parse/1` for conversion
  #   - Called by: `parse_line/1` for quantity field
  defp parse_int(string) do
    # Integer.parse/1 intenta convertir string a entero
    case Integer.parse(string) do
      # Éxito: retorna el número entero
      {number, _} -> number
      # Error: retorna átomo :error
      :error -> :error
    end
  end

  # Calcula el total de ventas
  # Fórmula: (precio * cantidad) - descuento
  #
  # ## Parameters
  #   - `records`: List of valid record maps
  #
  # ## Returns
  #   - Float: Total sales amount rounded to 2 decimal places
  #
  # ## Formula
  #   For each record: total += (price * quantity) * (1 - discount/100)
  #   Equivalent to: total += (price * quantity) - (price * quantity * discount/100)
  #
  # ## Communication
  #   - Uses: `Enum.reduce/3`, `Float.round/2`
  #   - Called by: `process/1` to calculate total_sales metric
  defp calculate_total(records) do
    # Enum.reduce/3 acumula valores empezando desde 0.0
    Enum.reduce(records, 0.0, fn record, total ->
      # Calcula venta bruta: precio * cantidad
      sale = record.price * record.quantity
      # Calcula monto del descuento: venta * (porcentaje/100)
      discount_amount = sale * (record.discount / 100)
      # Suma venta neta (bruta - descuento) al total acumulado
      total + (sale - discount_amount)
    end)
    # Redondea el resultado final a 2 decimales
    |> Float.round(2)
  end

  # Cuenta productos únicos en los registros
  #
  # ## Parameters
  #   - `records`: List of valid record maps
  #
  # ## Returns
  #   - Integer: Count of unique product names
  #
  # ## Communication
  #   - Uses: `Enum.map/2`, `Enum.uniq/1`, `length/1`
  #   - Called by: `process/1` to calculate unique_products metric
  defp count_unique(records) do
    records
    # Enum.map/2: extrae solo el campo .product de cada registro
    # & &1.product es shorthand para fn(record) -> record.product end
    |> Enum.map(& &1.product)
    # Enum.uniq/1: elimina valores duplicados de la lista
    |> Enum.uniq()
    # length/1: cuenta cuántos elementos únicos quedaron
    |> length()
  end
end
