defmodule FileProcessorWeb.Router do
  use FileProcessorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FileProcessorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FileProcessorWeb do
    pipe_through :browser

    # Página de inicio
    get "/", PageController, :home

    # Procesamiento — LiveView
    live "/processing", ProcessingLive

    # Historial de ejecuciones — controllers (por ahora)
    # IMPORTANTE: las rutas con segmentos fijos (/delete_all, /:id/download)
    # deben ir antes de las rutas con :id para que Phoenix no las interprete
    # como un id.
    delete "/executions/delete_all", ExecutionController, :delete_all
    get "/executions/:id/download", ExecutionController, :download
    live "/executions", ExecutionLive
    # get "/executions", ExecutionController, :index   #Controller
    get "/executions/:id", ExecutionController, :show
    delete "/executions/:id", ExecutionController, :delete
  end

  if Application.compile_env(:file_processor, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FileProcessorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
