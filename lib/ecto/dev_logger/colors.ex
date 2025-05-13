defmodule Ecto.DevLogger.Colors do
  @moduledoc """
  ANSI escape codes for colors
  """

  @doc """
  Colorize a message and reset color afterwards

  To disable colorization, pass an empty string as `reset_color`

  ## Examples
      iex> Ecto.DevLogger.Colors.colorize("hello", "\e[31m", "\e[0m")
      "\e[31mhello\e[0m"
      iex> Ecto.DevLogger.Colors.colorize("hello", "\e[31m", "")
      "hello"
  """
  @spec colorize(String.t(), String.t(), String.t()) :: String.t()
  def colorize(msg, _color, ""), do: msg
  def colorize(msg, color, reset_color), do: "#{color}#{msg}#{reset_color}"

  @colorize_step 25
  @doc """
  Returns colorized string for different time durations

  Durations below @colorize_step ms will not be colorized
  Every @colorize_step ms apply color gradient from RGB(5, 5, 0) to RGB(5, 0, 0)

  ## Examples
      iex> Enum.map(0..150//25, fn x -> Ecto.DevLogger.Colors.colorize_duration(x, "\e[0m") end)
      ["0ms", "25ms", "\e[38;5;220m50ms\e[0m", "\e[38;5;214m75ms\e[0m", "\e[38;5;208m100ms\e[0m", "\e[38;5;202m125ms\e[0m", "\e[38;5;196m150ms\e[0m"]
  """
  @spec colorize_duration(float(), String.t()) :: String.t()
  def colorize_duration(duration, reset_color) do
    if duration > @colorize_step do
      c = IO.ANSI.color(5, 5 - min(div(floor(duration) - @colorize_step, @colorize_step), 5), 0)
      colorize("#{duration}ms", c, reset_color)
    else
      "#{duration}ms"
    end
  end

  @doc """
  Returns color to be used for different SQL queries
  """
  @spec sql_color(String.t()) :: String.t()
  def sql_color(<<key::binary-size(3), _::binary>>) do
    %{
      "SEL" => IO.ANSI.light_cyan(),
      "ROL" => IO.ANSI.red(),
      "LOC" => IO.ANSI.white(),
      "INS" => IO.ANSI.green(),
      "UPD" => IO.ANSI.yellow(),
      "DEL" => IO.ANSI.red(),
      "BEG" => IO.ANSI.magenta(),
      "COM" => IO.ANSI.magenta()
    }
    |> Map.get(String.upcase(key), IO.ANSI.default_color())
  end

  @doc """
  Returns colorized string for different SQL queries

  ## Examples
      iex> Ecto.DevLogger.Colors.colorize_sql("SELECT * FROM users", "")
      "SELECT * FROM users"
      iex> Ecto.DevLogger.Colors.colorize_sql("SELECT * FROM users", "\e[0m")
      "\e[96mSELECT * FROM users\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("ROLLBACK TRANSACTION", "\e[0m")
      "\e[31mROLLBACK TRANSACTION\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("LOCK TABLE users", "\e[0m")
      "\e[37mLOCK TABLE users\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("INSERT INTO users (name) VALUES ('NAME')", "\e[0m")
      "\e[32mINSERT INTO users (name) VALUES ('NAME')\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("UPDATE users SET name='NAME'", "\e[0m")
      "\e[33mUPDATE users SET name='NAME'\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("DELETE FROM users", "\e[0m")
      "\e[31mDELETE FROM users\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("begin transaction", "\e[0m")
      "\e[35mbegin transaction\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("commit transaction", "\e[0m")
      "\e[35mcommit transaction\e[0m"
      iex> Ecto.DevLogger.Colors.colorize_sql("WTF??", "\e[0m")
      "\e[39mWTF??\e[0m"
  """
  @spec colorize_sql(String.t(), String.t()) :: String.t()
  def colorize_sql(query, ""), do: query
  def colorize_sql(query, reset_color), do: colorize(query, sql_color(query), reset_color)
end
