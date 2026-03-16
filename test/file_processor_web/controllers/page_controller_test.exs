defmodule FileProcessorWeb.PageControllerTest do
  use FileProcessorWeb.ConnCase

  test "GET / redirige a /processing", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/processing"
  end
end
