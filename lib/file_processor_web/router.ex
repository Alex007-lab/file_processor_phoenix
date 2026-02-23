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

    get "/", PageController, :home

    # Rutas específicas para executions (DEBEN ir ANTES de resources)
    delete "/executions/delete_all", ExecutionController, :delete_all
    get "/executions/:id/download", ExecutionController, :download

    # Recursos estándar - SIN except
    resources "/executions", ExecutionController

    # Rutas de procesamiento
    get "/processing", ProcessingController, :new
    post "/processing", ProcessingController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", FileProcessorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:file_processor, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FileProcessorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
