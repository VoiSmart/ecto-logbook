defmodule EctoLogbookTest.InlineTest do
  @moduledoc false

  use ExUnit.Case
  alias EctoLogbook.Inline

  @disable_color ""
  @params [
    <<95, 131, 49, 101, 176, 212, 77, 86, 178, 31, 80, 13, 41, 189, 148, 174>>,
    ["κόσμε", "te'st"],
    1
  ]

  describe "inline_params/4" do
    test "query is unchanged when there are no params" do
      assert Inline.inline_params("query $1 @2 ?", [], @disable_color, Ecto.Adapters.Postgres) ==
               "query $1 @2 ?"
    end

    test "query is unchanged when the adapter is not supported" do
      assert Inline.inline_params(
               "query $1 @2 ?",
               @params,
               @disable_color,
               Ecto.Adapters.UNKNOWN
             ) ==
               "query $1 @2 ?"
    end

    test "param is inspected when PrintableParameter.to_expression fails" do
      assert Inline.inline_params(
               ~s|SELECT $1|,
               [%ArgumentError{message: "TEST"}],
               @disable_color,
               Ecto.Adapters.Postgres
             ) ==
               ~s|SELECT %ArgumentError{message: "TEST"}|
    end

    test "Postgres" do
      assert Inline.inline_params(
               ~s|SELECT c0."name" FROM "posts" AS c0 WHERE (((c0."id" != $1) AND c0."type" = ANY($2)) OR (c0."priority?" = $3))|,
               @params,
               @disable_color,
               Ecto.Adapters.Postgres
             ) ==
               ~s|SELECT c0."name" FROM "posts" AS c0 WHERE (((c0."id" != '5f833165-b0d4-4d56-b21f-500d29bd94ae') AND c0."type" = ANY('{κόσμε,te''st}')) OR (c0."priority?" = 1))|
    end

    test "Tds" do
      assert Inline.inline_params(
               ~s|SELECT c0."name" FROM "posts" AS c0 WHERE (((c0."id" != @1) AND c0."type" = ANY(@2)) OR (c0."priority?" = @3))|,
               @params,
               @disable_color,
               Ecto.Adapters.Tds
             ) ==
               ~s|SELECT c0.\"name\" FROM \"posts\" AS c0 WHERE (((c0.\"id\" != '5f833165-b0d4-4d56-b21f-500d29bd94ae') AND c0.\"type\" = ANY('{κόσμε,te''st}')) OR (c0.\"priority?\" = 1))|
    end

    test "MySQL" do
      assert to_string(
               Inline.inline_params(
                 ~s|SELECT c0.\"name\" FROM \"posts\" AS c0 WHERE (((c0.\"id\" != ?) AND c0.\"type\" = ANY(?)) OR (c0.\"priority?\" = ?))|,
                 @params,
                 @disable_color,
                 Ecto.Adapters.MyXQL
               )
             ) ==
               ~s|SELECT c0.\"name\" FROM \"posts\" AS c0 WHERE (((c0.\"id\" != '5f833165-b0d4-4d56-b21f-500d29bd94ae') AND c0.\"type\" = ANY('{κόσμε,te''st}')) OR (c0.\"priority?\" = 1))|
    end

    test "SQLite3" do
      assert to_string(
               Inline.inline_params(
                 ~s|SELECT c0."name" FROM "posts" AS c0 WHERE (((c0."id" != ?1) AND c0."type" = ANY(?2)) OR (c0."priority" = ?3))|,
                 @params,
                 @disable_color,
                 Ecto.Adapters.SQLite3
               )
             ) ==
               ~s|SELECT c0."name" FROM "posts" AS c0 WHERE (((c0."id" != '5f833165-b0d4-4d56-b21f-500d29bd94ae') AND c0."type" = ANY('{κόσμε,te''st}')) OR (c0."priority" = 1))|
    end
  end
end
