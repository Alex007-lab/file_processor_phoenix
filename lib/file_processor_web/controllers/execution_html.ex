defmodule FileProcessorWeb.ExecutionHTML do
  use FileProcessorWeb, :html

  embed_templates "execution_html/*"

  @doc """
  Renders a execution form.

  The form is defined in the template at
  execution_html/execution_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def execution_form(assigns)
end
