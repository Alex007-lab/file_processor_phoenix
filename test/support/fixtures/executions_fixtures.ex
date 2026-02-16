defmodule FileProcessor.ExecutionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FileProcessor.Executions` context.
  """

  @doc """
  Generate a execution.
  """
  def execution_fixture(attrs \\ %{}) do
    {:ok, execution} =
      attrs
      |> Enum.into(%{
        files: "some files",
        mode: "some mode",
        result: "some result",
        timestamp: ~U[2026-02-14 06:39:00Z],
        total_time: 42
      })
      |> FileProcessor.Executions.create_execution()

    execution
  end
end
