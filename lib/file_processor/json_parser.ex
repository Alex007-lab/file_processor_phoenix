defmodule JsonParser do
  # Documentación del módulo
  @moduledoc """
  JSON parser for user data using Jason library.

  This module provides functionality to parse JSON files containing user and session data.
  It extracts metrics such as total users, active users, and session counts.

  Expected JSON structure:
  {
    "usuarios": [
      {"id": 1, "nombre": "Juan", "activo": true},
      ...
    ],
    "sesiones": [
      {"id": 1, "usuario_id": 1, "duracion": 3600},
      ...
    ]
  }

  ## Functions

  ### Public Functions
  - `process/1` - Main function to process JSON files

  ### Private Functions
  - `count_active/1` - Counts active users from user list
  """

  @doc """
  Main function to process JSON files.

  Reads a JSON file, parses its content, and extracts user and session metrics.

  ## Parameters
    - `file_path`: String path to the JSON file

  ## Returns
    - `{:ok, metrics}` on success, where metrics is a map containing:
      - `total_users`: Total number of users in the file
      - `active_users`: Number of users with "activo": true
      - `total_sessions`: Total number of sessions in the file
      - `file_name`: Base name of the processed file
    - `{:error, reason}` on failure, where reason describes the error

  ## Communication
    - Uses: `File.exists?/1`, `File.read!/1`, `Jason.decode!/1`, `Map.get/3`, `Path.basename/1`
    - Calls private function: `count_active/1`
    - Handles specific exceptions: `Jason.DecodeError`

  ## Examples
      iex> JsonParser.process("users.json")
      {:ok, %{total_users: 50, active_users: 32, total_sessions: 120, file_name: "users.json"}}

      iex> JsonParser.process("invalid.json")
      {:error, "Invalid JSON format"}

      iex> JsonParser.process("nonexistent.json")
      {:error, "File not found: nonexistent.json"}
  """
  def process(file_path) do
    # Verifica si el archivo existe usando File.exists?/1
    if File.exists?(file_path) do
      # Bloque try para capturar errores durante el procesamiento
      try do
        # Lee todo el contenido del archivo
        # File.read!/1 lee el contenido completo como string binario
        # ¡Lanza excepción si el archivo no se puede leer!
        content = File.read!(file_path)

        # Decodifica JSON a estructura de datos Elixir usando Jason
        # Jason.decode!/1 convierte string JSON a mapa/listas de Elixir
        # ¡Lanza Jason.DecodeError si el JSON es inválido!
        data = Jason.decode!(content)

        # Obtiene lista de usuarios del mapa decodificado
        # Map.get/3 obtiene valor de la clave "usuarios" o retorna lista vacía [] si no existe
        # data es un mapa con claves JSON como strings
        users = Map.get(data, "usuarios", [])

        # Obtiene lista de sesiones (similar a usuarios)
        # Si no existe la clave "sesiones", retorna lista vacía
        sessions = Map.get(data, "sesiones", [])

        # Crea mapa de métricas con los datos extraídos
        metrics = %{
          # Total de usuarios: longitud de la lista users
          # length/1 retorna número de elementos en la lista
          total_users: length(users),

          # Usuarios activos: llama a función privada count_active/1
          # Pasa la lista de usuarios para contar cuántos tienen "activo": true
          active_users: count_active(users),

          # Total de sesiones: longitud de la lista sessions
          total_sessions: length(sessions),

          # Nombre del archivo: extrae solo el nombre sin la ruta completa
          # Path.basename/1 retorna el último componente de la ruta
          file_name: Path.basename(file_path)
        }

        # Retorna tupla de éxito con el mapa de métricas
        {:ok, metrics}

      rescue
        # Captura error específico de decodificación JSON
        # Jason.DecodeError se lanza cuando el JSON tiene formato inválido
        Jason.DecodeError ->
          {:error, "Invalid JSON format"}

        # Captura cualquier otro error (fallback genérico)
        # inspect/1 convierte el error a string legible para debugging
        error ->
          {:error, "JSON parsing error: #{inspect(error)}"}
      end
    else
      # Archivo no encontrado - retorna tupla de error
      {:error, "File not found: #{file_path}"}
    end
  end

  # Función privada para contar usuarios activos
  #
  # ## Parameters
  #   - `users`: List of user maps where each map may contain "activo" key
  #
  # ## Returns
  #   - Integer: Count of users with "activo": true
  #
  # ## Notes
  #   - Assumes each user map has a boolean "activo" field
  #   - Users without "activo" field or with "activo": false are not counted
  #   - Users with "activo": true are counted (Elixir truthy: true, false, nil)
  #
  # ## Communication
  #   - Uses: `Enum.count/2` with anonymous function
  #   - Called by: `process/1` to calculate active_users metric
  defp count_active(users) do
    # Enum.count/2 cuenta elementos que cumplen la condición
    # Recorre la lista users y aplica la función anónima a cada elemento
    # & &1["activo"] es shorthand para: fn(user) -> user["activo"] end
    # En Elixir, solo true es truthy (false y nil son falsy)
    # Por lo tanto, solo cuenta usuarios con user["activo"] == true
    Enum.count(users, & &1["activo"])
  end
end
