defmodule FileProcessor.ExecutionsFixtures do
  @moduledoc """
  Helpers para crear ejecuciones en tests.
  """

  alias FileProcessor.Executions

  def execution_fixture(attrs \\ %{}) do
    {:ok, execution} =
      attrs
      |> Enum.into(%{
        files:      "ventas.csv",
        mode:       "sequential",
        result:     "• Estado: éxito\n• Registros válidos: 10",
        status:     "success",
        timestamp:  ~U[2026-02-14 06:39:00Z],
        total_time: 42
      })
      |> Executions.create_execution()

    execution
  end

  def execution_fixture_parallel(attrs \\ %{}) do
    execution_fixture(Map.merge(%{mode: "parallel", files: "usuarios.json"}, attrs))
  end

  def execution_fixture_benchmark(attrs \\ %{}) do
    execution_fixture(Map.merge(%{
      mode:   "benchmark",
      files:  "ventas.csv",
      result: "📈 Secuencial: 100 ms\n⚡ Paralelo:    60 ms"
    }, attrs))
  end

  def execution_fixture_partial(attrs \\ %{}) do
    execution_fixture(Map.merge(%{
      status: "partial",
      result: "• Estado: parcial\n• Registros válidos: 3"
    }, attrs))
  end
end
