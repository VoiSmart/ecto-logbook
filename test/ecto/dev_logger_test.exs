defmodule Ecto.DevLoggerTest do
  Code.require_file("fixtures.ex", __DIR__)

  use ExUnit.Case
  import ExUnit.CaptureLog

  setup do
    setup_repo(Repo)

    Ecto.DevLogger.install(Repo,
      colorize: false,
      log_repo_name: true,
      inline_params: true,
      # debug_telemetry_metadata: true,
      before_inline_callback: fn query -> String.replace(query, "\"", "") end
    )

    on_exit(fn ->
      Ecto.DevLogger.uninstall(Repo)
      Repo.get_config() |> Repo.__adapter__().storage_down()
    end)
  end

  test "install returns error from failure to attach " do
    assert {:error, :already_exists} = Ecto.DevLogger.install(Repo)
  end

  test "handler_id\1" do
    assert Ecto.DevLogger.handler_id(Repo) == [:ecto_dev_logger, :repo]
  end

  test "INSERT SELECT UPDATE DELETE" do
    post = %Post{
      string: "Post 1",
      map: %{test: true, string: "string"},
      integer: 0,
      decimal: Decimal.from_float(0.12),
      date: ~D[2024-08-01],
      time: ~T[21:23:53],
      array_of_strings: ["hello", "world"],
      datetime: ~U[2024-08-01 21:23:53.845311Z],
      naive_datetime: ~N[2024-08-01 21:23:53.846380],
      array_of_enums: [:foo, :baz],
      enum: :bar
    }

    assert capture_log(fn -> Repo.insert!(post) end) =~
             ~s|INSERT INTO posts (integer,date,time,string,map,enum,decimal,array_of_strings,datetime,naive_datetime,array_of_enums) VALUES (0,'2024-08-01','21:23:53','Post 1','{"string":"string","test":true}','bar',0.12,'{hello,world}','2024-08-01 21:23:53.845311Z','2024-08-01 21:23:53.846380','{foo,baz}') RETURNING id|
             |> String.replace("\"", "\\\"")

    assert capture_log(fn -> Repo.all(Post) end) =~
             ~s|SELECT p0.id, p0.string, p0.binary, p0.map, p0.integer, p0.decimal, p0.date, p0.time, p0.array_of_strings, p0.datetime, p0.naive_datetime, p0.password_digest, p0.array_of_enums, p0.enum FROM posts AS p0|

    assert capture_log(fn -> Repo.update_all(Post, set: [string: nil]) end) =~
             "UPDATE posts AS p0 SET string = NULL"

    assert capture_log(fn -> Repo.delete_all(Post) end) =~ "DELETE FROM posts AS p0"
  end

  describe "generates correct sql for structs" do
    test "array of enums field" do
      log = capture_log(fn -> Repo.insert!(%Post{array_of_enums: [:foo, :baz]}) end)
      assert log =~ ~S|INSERT INTO posts (array_of_enums) VALUES ('{foo,baz}') RETURNING id|
    end

    test "enum field" do
      log = capture_log(fn -> Repo.insert!(%Post{enum: :bar}) end)
      assert log =~ ~S|INSERT INTO posts (enum) VALUES ('bar') RETURNING id|
    end
  end

  describe "multiple repos" do
    setup do
      setup_repo(Repo2)

      on_exit(fn ->
        Ecto.DevLogger.uninstall(Repo2)
        Repo2.get_config() |> Repo2.__adapter__().storage_down()
      end)
    end

    test "install of second repo works" do
      assert :ok = Ecto.DevLogger.install(Repo2)
      repo1_prefix = Repo.config()[:telemetry_prefix]
      [repo1_handler] = :telemetry.list_handlers(repo1_prefix)
      repo2_prefix = Repo2.config()[:telemetry_prefix]
      [repo2_handler] = :telemetry.list_handlers(repo2_prefix)
      # Confirm that there is a distinct handler ID for each repo
      assert repo1_handler.id != repo2_handler.id
    end

    test "scond repos does not inlines params" do
      assert :ok = Ecto.DevLogger.install(Repo2)

      assert capture_log(fn -> Repo2.insert!(%Post{array_of_enums: [:foo, :baz]}) end) =~
               ~S|INSERT INTO "posts" ("array_of_enums") VALUES (?1) RETURNING "id" [[:foo, :baz]]|
               |> String.replace("\"", "\\\"")
    end
  end

  defp setup_repo(repo) do
    config = repo.get_config()
    Application.put_env(:test, repo, config)
    repo.__adapter__().storage_down(config)
    repo.__adapter__().storage_up(config)
    repo_pid = start_supervised!(repo)

    repo.query!(
      """
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        string text,
        "binary" bytea,
        map jsonb,
        integer integer,
        decimal numeric,
        date date,
        time time(0),
        array_of_strings text[],
        password_digest text,
        datetime timestamp,
        naive_datetime timestamp,
        array_of_enums integer[],
        enum integer
      )
      """,
      []
    )

    repo_pid
  end
end
