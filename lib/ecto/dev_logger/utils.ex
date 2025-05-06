defmodule Ecto.DevLogger.Utils do
  @moduledoc false

  alias Ecto.DevLogger.PrintableParameter

  @spec in_string_quotes(String.t()) :: String.t()
  def in_string_quotes(string) do
    "'#{String.replace(string, "'", "''")}'"
  end

  @doc """
  Takes a list of elements and returns `{:ok, list_with_string_literals}`

  Where `list_with_string_literals` is a list of tuples `{element, string_literal}`
  and `string_literal` is a string literal representation of `element`.

  Returns `:error` if at least one element does not have a string literal representation
  """
  @spec all_to_string_literal([any()]) :: {:ok, [{any(), String.t()}]} | :error
  def all_to_string_literal(list) do
    result =
      Enum.reduce_while(list, {:ok, []}, fn element, {:ok, acc} ->
        case PrintableParameter.to_string_literal(element) do
          nil -> {:halt, :error}
          string_literal -> {:cont, {:ok, [{element, string_literal} | acc]}}
        end
      end)

    with {:ok, list} <- result, do: {:ok, Enum.reverse(list)}
  end
end

defmodule Ecto.DevLogger.NumericEnum do
  @moduledoc false
  @type t :: %__MODULE__{integer: integer(), atom: atom()}
  defstruct [:integer, :atom]
end
