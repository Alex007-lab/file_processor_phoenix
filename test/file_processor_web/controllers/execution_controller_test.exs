defmodule FileProcessorWeb.ExecutionControllerTest do
  use FileProcessorWeb.ConnCase

  import FileProcessor.ExecutionsFixtures

  @create_attrs %{timestamp: ~U[2026-02-14 06:39:00Z], mode: "some mode", result: "some result", files: "some files", total_time: 42}
  @update_attrs %{timestamp: ~U[2026-02-15 06:39:00Z], mode: "some updated mode", result: "some updated result", files: "some updated files", total_time: 43}
  @invalid_attrs %{timestamp: nil, mode: nil, result: nil, files: nil, total_time: nil}

  describe "index" do
    test "lists all executions", %{conn: conn} do
      conn = get(conn, ~p"/executions")
      assert html_response(conn, 200) =~ "Listing Executions"
    end
  end

  describe "new execution" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/executions/new")
      assert html_response(conn, 200) =~ "New Execution"
    end
  end

  describe "create execution" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/executions", execution: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/executions/#{id}"

      conn = get(conn, ~p"/executions/#{id}")
      assert html_response(conn, 200) =~ "Execution #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/executions", execution: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Execution"
    end
  end

  describe "edit execution" do
    setup [:create_execution]

    test "renders form for editing chosen execution", %{conn: conn, execution: execution} do
      conn = get(conn, ~p"/executions/#{execution}/edit")
      assert html_response(conn, 200) =~ "Edit Execution"
    end
  end

  describe "update execution" do
    setup [:create_execution]

    test "redirects when data is valid", %{conn: conn, execution: execution} do
      conn = put(conn, ~p"/executions/#{execution}", execution: @update_attrs)
      assert redirected_to(conn) == ~p"/executions/#{execution}"

      conn = get(conn, ~p"/executions/#{execution}")
      assert html_response(conn, 200) =~ "some updated files"
    end

    test "renders errors when data is invalid", %{conn: conn, execution: execution} do
      conn = put(conn, ~p"/executions/#{execution}", execution: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Execution"
    end
  end

  describe "delete execution" do
    setup [:create_execution]

    test "deletes chosen execution", %{conn: conn, execution: execution} do
      conn = delete(conn, ~p"/executions/#{execution}")
      assert redirected_to(conn) == ~p"/executions"

      assert_error_sent 404, fn ->
        get(conn, ~p"/executions/#{execution}")
      end
    end
  end

  defp create_execution(_) do
    execution = execution_fixture()

    %{execution: execution}
  end
end
