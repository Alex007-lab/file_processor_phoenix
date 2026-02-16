defmodule FileProcessor.ExecutionsTest do
  use FileProcessor.DataCase

  alias FileProcessor.Executions

  describe "executions" do
    alias FileProcessor.Executions.Execution

    import FileProcessor.ExecutionsFixtures

    @invalid_attrs %{timestamp: nil, mode: nil, result: nil, files: nil, total_time: nil}

    test "list_executions/0 returns all executions" do
      execution = execution_fixture()
      assert Executions.list_executions() == [execution]
    end

    test "get_execution!/1 returns the execution with given id" do
      execution = execution_fixture()
      assert Executions.get_execution!(execution.id) == execution
    end

    test "create_execution/1 with valid data creates a execution" do
      valid_attrs = %{timestamp: ~U[2026-02-14 06:39:00Z], mode: "some mode", result: "some result", files: "some files", total_time: 42}

      assert {:ok, %Execution{} = execution} = Executions.create_execution(valid_attrs)
      assert execution.timestamp == ~U[2026-02-14 06:39:00Z]
      assert execution.mode == "some mode"
      assert execution.result == "some result"
      assert execution.files == "some files"
      assert execution.total_time == 42
    end

    test "create_execution/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Executions.create_execution(@invalid_attrs)
    end

    test "update_execution/2 with valid data updates the execution" do
      execution = execution_fixture()
      update_attrs = %{timestamp: ~U[2026-02-15 06:39:00Z], mode: "some updated mode", result: "some updated result", files: "some updated files", total_time: 43}

      assert {:ok, %Execution{} = execution} = Executions.update_execution(execution, update_attrs)
      assert execution.timestamp == ~U[2026-02-15 06:39:00Z]
      assert execution.mode == "some updated mode"
      assert execution.result == "some updated result"
      assert execution.files == "some updated files"
      assert execution.total_time == 43
    end

    test "update_execution/2 with invalid data returns error changeset" do
      execution = execution_fixture()
      assert {:error, %Ecto.Changeset{}} = Executions.update_execution(execution, @invalid_attrs)
      assert execution == Executions.get_execution!(execution.id)
    end

    test "delete_execution/1 deletes the execution" do
      execution = execution_fixture()
      assert {:ok, %Execution{}} = Executions.delete_execution(execution)
      assert_raise Ecto.NoResultsError, fn -> Executions.get_execution!(execution.id) end
    end

    test "change_execution/1 returns a execution changeset" do
      execution = execution_fixture()
      assert %Ecto.Changeset{} = Executions.change_execution(execution)
    end
  end
end
