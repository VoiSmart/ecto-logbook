defmodule Repo do
  use Ecto.Repo, adapter: Ecto.Adapters.SQLite3, otp_app: :test

  def get_config() do
    [
      log: false,
      otp_app: :test,
      database: ":memory:",
      stacktrace: true,
      pool_size: 1
    ]
  end
end

defmodule Repo2 do
  use Ecto.Repo, adapter: Ecto.Adapters.SQLite3, otp_app: :test

  def get_config() do
    [
      log: false,
      otp_app: :test,
      database: ":memory:",
      stacktrace: false,
      pool_size: 1
    ]
  end
end

defmodule Post do
  use Ecto.Schema
  @enum [foo: 1, bar: 2, baz: 5]

  @primary_key {:id, :id, read_after_writes: true}
  schema "posts" do
    field(:string, :string)
    field(:binary, :binary)
    field(:map, :map)
    field(:integer, :integer)
    field(:decimal, :decimal)
    field(:date, :date)
    field(:time, :time)
    field(:array_of_strings, {:array, :string})
    field(:datetime, :utc_datetime_usec)
    field(:naive_datetime, :naive_datetime_usec)
    field(:password_digest, :string)
    field(:array_of_enums, {:array, Ecto.Enum}, values: @enum)
    field(:enum, Ecto.Enum, values: @enum)
  end
end
