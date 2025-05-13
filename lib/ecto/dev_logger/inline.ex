defmodule Ecto.DevLogger.Inline do
  @moduledoc """
  Replaces query parameters with their values
  """

  alias Ecto.DevLogger.Colors
  alias Ecto.DevLogger.PrintableParameter

  @spec inline_value(any(), String.t()) :: String.t()
  defp inline_value(value, reset_color) do
    value
    |> PrintableParameter.to_expression()
    |> Colors.colorize(IO.ANSI.light_blue(), reset_color)
  rescue
    Protocol.UndefinedError ->
      value
      |> inspect()
      |> Colors.colorize(IO.ANSI.light_blue(), reset_color)
  end

  @spec reduce_query_params([String.t()], [any()], String.t(), String.t()) :: String.t()
  defp reduce_query_params([], _params, _color, acc), do: acc

  defp reduce_query_params([part | parts], [param | params], color, acc) do
    reduce_query_params(parts, params, color, acc <> part <> inline_value(param, color))
  end

  defp reduce_query_params([part | parts], [], color, acc) do
    reduce_query_params(parts, [], color, acc <> part)
  end

  @doc """
  Substitutes parameters placeholders in `query` with their actual values
  """
  @spec inline_params(String.t(), [any()], String.t(), module()) :: String.t()
  def inline_params(query, [], _color, _repo_adapter), do: query

  def inline_params(query, params, reset_color, Ecto.Adapters.Postgres) do
    String.split(query, ~r/\$\d+/) |> reduce_query_params(params, reset_color, "")
  end

  def inline_params(query, params, reset_color, Ecto.Adapters.Tds) do
    String.split(query, ~r/\@\d+/) |> reduce_query_params(params, reset_color, "")
  end

  def inline_params(query, params, reset_color, Ecto.Adapters.MyXQL) do
    String.split(query, ~r/\?(?!")/) |> reduce_query_params(params, reset_color, "")
  end

  def inline_params(query, params, reset_color, Ecto.Adapters.SQLite3) do
    String.split(query, ~r/\?\d*/) |> reduce_query_params(params, reset_color, "")
  end

  def inline_params(query, _params, _reset_color, _repo_adapter) do
    query
  end
end
