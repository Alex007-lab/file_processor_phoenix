defmodule FileProcessorWeb.PageController do
  use FileProcessorWeb, :controller

  def home(conn, _params) do
    # Redirigir directamente al formulario de procesamiento
    redirect(conn, to: ~p"/processing")
  end
end
