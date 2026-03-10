defmodule FileProcessorWeb.ExecutionHTML do
  use FileProcessorWeb, :html

  alias FileProcessor.ExecutionHelpers

  embed_templates "execution_html/*"

  @doc """
  Construye la lista de mapas de archivos para mostrar en la vista de detalle.

  Para cada archivo de la ejecución extrae su sección del reporte,
  sus métricas y determina su estado visual.

  ## Retorna

  Lista de mapas con:
    - `:name`         — nombre del archivo
    - `:extension`    — extensión con punto
    - `:details`      — bloque de texto del reporte para ese archivo
    - `:metrics`      — mapa de métricas según tipo de archivo
    - `:has_error`    — booleano indicando si hubo error
    - `:status_class` — clase CSS del badge de estado
    - `:status_text`  — texto del badge de estado
  """
  def parse_execution_files(execution) do
    execution
    |> Map.fetch!(:files)
    |> String.split(", ", trim: true)
    |> Enum.map(fn file ->
      extension   = Path.extname(file)
      details     = ExecutionHelpers.extract_file_section(execution.result, file)
      metrics     = ExecutionHelpers.extract_metrics(details, extension)
      has_error   = error?(details)

      %{
        name:         file,
        extension:    extension,
        details:      details,
        metrics:      metrics,
        has_error:    has_error,
        status_class: if(has_error, do: "badge-warning", else: "badge-success"),
        status_text:  if(has_error, do: "Parcial", else: "Éxito")
      }
    end)
  end

  @doc """
  Devuelve un mapa con el resumen general de la ejecución para las tarjetas
  de la vista de detalle.

  Extrae `successes` y `errors` del texto del reporte buscando la línea
  que los registra al construir el reporte en `ProcessingController`.

  ## Retorna

  `%{total_time, successes, errors, total_files}`
  """
  def get_execution_summary(execution) do
    {successes, errors} =
      case Regex.run(~r/✅ Exitosos:\s*(\d+).*?❌ Errores:\s*(\d+)/s, execution.result) do
        [_, s, e] -> {String.to_integer(s), String.to_integer(e)}
        nil       -> {0, 0}
      end

    %{
      total_time:  execution.total_time,
      successes:   successes,
      errors:      errors,
      total_files: successes + errors
    }
  end

  # ---------------------------------------------------------------------------
  # Privadas
  # ---------------------------------------------------------------------------

  # Determina si el bloque de texto de un archivo indica un error.
  # Se considera error si no se encontró sección o si el texto lo indica.
  defp error?(details) do
    details == "No se encontraron resultados para este archivo" or
      String.contains?(details, "• Estado: error") or
      String.contains?(details, "- ERROR")
  end
end
