defprotocol Ecto.DevLogger.PrintableParameter do
  @moduledoc """
  A protocol to print various data structures as valid SQL expressions.

  `to_expression/1` is the main function and `to_string_literal/1` is an optional helper for it.

  `Ecto.DevLogger` tries to represent complex terms, like arrays (lists) and composite types (tuples)
  as string literal first. Not all terms are easy/efficient/whatever to represent as strings, so if
  `to_string_literal/1` returns a string for all elements inside the array,
  then array will be represented as string as well. Otherwise, array will be represented using `ARRAY` constructor:

      iex> Ecto.DevLogger.PrintableParameter.to_expression(["Elixir", "Ecto"])
      "'{Elixir,Ecto}'"

      iex> Ecto.DevLogger.PrintableParameter.to_expression(["Elixir", "Ecto", <<153>>])
      "ARRAY['Elixir','Ecto',DECODE('mQ==','BASE64')]"

  The same is true for composite types (tuples):

      iex> Ecto.DevLogger.PrintableParameter.to_expression({"Elixir", "Ecto"})
      "'(Elixir,Ecto)'"

      iex> Ecto.DevLogger.PrintableParameter.to_expression({"Elixir", "Ecto", <<153>>})
      "ROW('Elixir','Ecto',DECODE('mQ==','BASE64'))"
  """

  @doc """
  Converts term to a valid SQL expression.
  """
  @spec to_expression(any()) :: String.t()
  def to_expression(term)

  @doc """
  Converts term to a string literal.
  """
  @spec to_string_literal(any()) :: String.t() | nil
  def to_string_literal(term)
end

defimpl Ecto.DevLogger.PrintableParameter, for: Atom do
  def to_expression(nil), do: "NULL"
  def to_expression(true), do: "true"
  def to_expression(false), do: "false"
  def to_expression(atom), do: Ecto.DevLogger.Utils.in_string_quotes("#{atom}")

  def to_string_literal(nil), do: "NULL"
  def to_string_literal(true), do: "true"
  def to_string_literal(false), do: "false"
  def to_string_literal(atom), do: Atom.to_string(atom)
end

defimpl Ecto.DevLogger.PrintableParameter, for: Map do
  def to_expression(map) do
    map |> to_string_literal() |> Ecto.DevLogger.Utils.in_string_quotes()
  end

  def to_string_literal(map), do: Jason.encode!(map)
end

if Code.ensure_loaded?(Geo.Point) do
  defimpl Ecto.DevLogger.PrintableParameter, for: Geo.Point do
    def to_expression(point) do
      point |> to_string_literal() |> Ecto.DevLogger.Utils.in_string_quotes()
    end

    def to_string_literal(point), do: Jason.encode!(point)
  end
end

if Code.ensure_loaded?(Geo.Polygon) do
  defimpl Ecto.DevLogger.PrintableParameter, for: Geo.Polygon do
    def to_expression(point) do
      point |> to_string_literal() |> Ecto.DevLogger.Utils.in_string_quotes()
    end

    def to_string_literal(point), do: Jason.encode!(point)
  end
end

defimpl Ecto.DevLogger.PrintableParameter, for: Tuple do
  def to_expression(tuple) do
    case to_string_literal(tuple) do
      nil ->
        "ROW(" <>
          Enum.map_join(
            Tuple.to_list(tuple),
            ",",
            &Ecto.DevLogger.PrintableParameter.to_expression/1
          ) <> ")"

      value ->
        Ecto.DevLogger.Utils.in_string_quotes(value)
    end
  end

  def to_string_literal(tuple) do
    case Ecto.DevLogger.Utils.all_to_string_literal(Tuple.to_list(tuple)) do
      :error ->
        nil

      {:ok, list} ->
        body =
          Enum.map_join(list, ",", fn
            {nil, _literal} -> nil
            {"", _literal} -> ~s|""|
            {_, literal} -> escape_literal(literal)
          end)

        "(" <> body <> ")"
    end
  end

  defp escape_literal(literal) do
    string = String.replace(literal, "\"", "\\\"")

    if String.contains?(string, [",", "(", ")"]) do
      ~s|"#{string}"|
    else
      string
    end
  end
end

defimpl Ecto.DevLogger.PrintableParameter, for: Decimal do
  def to_expression(decimal), do: to_string_literal(decimal)
  def to_string_literal(decimal), do: Decimal.to_string(decimal)
end

defimpl Ecto.DevLogger.PrintableParameter, for: Integer do
  def to_expression(integer), do: to_string_literal(integer)
  def to_string_literal(integer), do: Integer.to_string(integer)
end

defimpl Ecto.DevLogger.PrintableParameter, for: Float do
  def to_expression(float), do: to_string_literal(float)
  def to_string_literal(float), do: Float.to_string(float)
end

defimpl Ecto.DevLogger.PrintableParameter, for: Date do
  def to_expression(date) do
    date
    |> to_string_literal()
    |> Ecto.DevLogger.Utils.in_string_quotes()
  end

  def to_string_literal(date), do: Date.to_string(date)
end

defimpl Ecto.DevLogger.PrintableParameter, for: DateTime do
  def to_expression(date_time) do
    date_time
    |> to_string_literal()
    |> Ecto.DevLogger.Utils.in_string_quotes()
  end

  def to_string_literal(date_time), do: DateTime.to_string(date_time)
end

defimpl Ecto.DevLogger.PrintableParameter, for: NaiveDateTime do
  def to_expression(naive_date_time) do
    naive_date_time
    |> to_string_literal()
    |> Ecto.DevLogger.Utils.in_string_quotes()
  end

  def to_string_literal(naive_date_time), do: NaiveDateTime.to_string(naive_date_time)
end

defimpl Ecto.DevLogger.PrintableParameter, for: Time do
  def to_expression(time) do
    time
    |> to_string_literal()
    |> Ecto.DevLogger.Utils.in_string_quotes()
  end

  def to_string_literal(time), do: Time.to_string(time)
end

defimpl Ecto.DevLogger.PrintableParameter, for: BitString do
  def to_expression(binary) do
    if String.valid?(binary) do
      Ecto.DevLogger.Utils.in_string_quotes(binary)
    else
      "DECODE('#{Base.encode64(binary)}','BASE64')"
    end
  end

  def to_string_literal(binary) do
    if String.valid?(binary) do
      binary
    end
  end
end

defimpl Ecto.DevLogger.PrintableParameter, for: List do
  def to_expression(list) do
    case to_string_literal(list) do
      nil ->
        "ARRAY[" <>
          Enum.map_join(list, ",", &Ecto.DevLogger.PrintableParameter.to_expression/1) <> "]"

      value ->
        Ecto.DevLogger.Utils.in_string_quotes(value)
    end
  end

  def to_string_literal(list) do
    case {list, Ecto.DevLogger.Utils.all_to_string_literal(list)} do
      {_, :error} ->
        nil

      {[%{__struct__: Postgrex.Lexeme} | _], {:ok, elements_with_literals}} ->
        Enum.map_join(elements_with_literals, " ", fn {_el, literal} -> literal end)

      {_, {:ok, elements_with_literals}} ->
        body =
          Enum.map_join(elements_with_literals, ",", fn
            {element, literal} when is_list(element) or is_nil(element) -> literal
            {"", _literal} -> ~s|""|
            {_element, literal} -> escape_literal(literal)
          end)

        "{" <> body <> "}"
    end
  end

  defp escape_literal(literal) do
    string = String.replace(literal, "\"", "\\\"")

    cond do
      String.downcase(string) == "null" -> ~s|"#{string}"|
      String.contains?(string, [",", "{", "}"]) -> ~s|"#{string}"|
      true -> string
    end
  end
end

if Code.ensure_loaded?(Postgrex.MACADDR) do
  defimpl Ecto.DevLogger.PrintableParameter, for: Postgrex.MACADDR do
    def to_expression(macaddr) do
      macaddr
      |> to_string_literal()
      |> Ecto.DevLogger.Utils.in_string_quotes()
    end

    def to_string_literal(macaddr) do
      macaddr.address
      |> Tuple.to_list()
      |> Enum.map_join(":", fn value ->
        value
        |> Integer.to_string(16)
        |> String.pad_leading(2, "0")
      end)
    end
  end
end

if Code.ensure_loaded?(Postgrex.Interval) do
  defimpl Ecto.DevLogger.PrintableParameter, for: Postgrex.Interval do
    def to_expression(struct),
      do: Postgrex.Interval.to_string(struct) |> Ecto.DevLogger.Utils.in_string_quotes()

    def to_string_literal(struct),
      do: Postgrex.Interval.to_string(struct)
  end
end

if Code.ensure_loaded?(Postgrex.INET) do
  defimpl Ecto.DevLogger.PrintableParameter, for: Postgrex.INET do
    def to_expression(inet) do
      inet
      |> to_string_literal()
      |> Ecto.DevLogger.Utils.in_string_quotes()
    end

    def to_string_literal(inet) do
      netmask =
        case inet.netmask do
          nil -> ""
          netmask -> "/#{netmask}"
        end

      "#{:inet.ntoa(inet.address)}#{netmask}"
    end
  end
end

if Code.ensure_loaded?(Postgrex.Lexeme) do
  defimpl Ecto.DevLogger.PrintableParameter, for: Postgrex.Lexeme do
    def to_expression(lexeme) do
      raise "Invalid parameter: #{inspect(lexeme)} must be inside a list"
    end

    def to_string_literal(lexeme) do
      word =
        if String.contains?(lexeme.word, [",", "'", " ", ":"]) do
          Ecto.DevLogger.Utils.in_string_quotes(lexeme.word)
        else
          lexeme.word
        end

      case lexeme.positions do
        [] ->
          word

        positions ->
          positions =
            Enum.map_join(positions, ",", fn
              {position, nil} -> Integer.to_string(position)
              {position, :D} -> Integer.to_string(position)
              {position, weight} -> [Integer.to_string(position), Atom.to_string(weight)]
            end)

          "#{word}:#{positions}"
      end
    end
  end
end

defimpl Ecto.DevLogger.PrintableParameter, for: Ecto.DevLogger.NumericEnum do
  def to_expression(enum), do: "#{enum.integer}/*#{enum.atom}*/"
  def to_string_literal(_numeric_enum), do: nil
end
