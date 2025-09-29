defmodule EctoLogbookTest.PrintableParameterTest do
  use ExUnit.Case, async: true

  alias Postgrex.{INET, Interval, Lexeme, MACADDR}

  doctest EctoLogbook.PrintableParameter
  import EctoLogbook.PrintableParameter

  describe "to_expression/1" do
    test "Atom" do
      assert to_expression(nil) == "NULL"
      assert to_expression(true) == "true"
      assert to_expression(false) == "false"
      assert to_expression(:hey) == "'hey'"
      assert to_expression(:hey@hey) == "'hey@hey'"
    end

    test "Numbers" do
      assert to_expression(-123) == "-123"
      assert to_expression(123) == "123"
      assert to_expression(123.12) == "123.12"
      assert to_expression(-123.12) == "-123.12"
      assert to_expression(Decimal.from_float(-123.12)) == "-123.12"
      assert to_expression(Decimal.from_float(123.12)) == "123.12"
    end

    test "Strings" do
      assert to_expression("") == ~s|''|
      assert to_expression("string with single quote: '") == ~s|'string with single quote: '''|
      assert to_expression("string with double quote: \"") == ~s|'string with double quote: "'|
      assert to_expression(<<95, 131, 49, 101, 176, 212>>) == "DECODE('X4MxZbDU','BASE64')"
      string_uuid = "c78073b9-7bd3-4465-88e4-dc647aa1d025"
      assert to_expression(string_uuid) == ~s|'c78073b9-7bd3-4465-88e4-dc647aa1d025'|
      binary_uuid = <<79, 208, 231, 171, 38, 209, 76, 228, 170, 26, 41, 3, 45, 16, 79, 73>>
      assert to_expression(binary_uuid) == "'4fd0e7ab-26d1-4ce4-aa1a-29032d104f49'"
      binary_ulid = <<1, 150, 166, 102, 15, 218, 236, 148, 23, 193, 20, 233, 118, 145, 114, 127>>
      assert to_expression(binary_ulid) == "'0196a666-0fda-ec94-17c1-14e97691727f'"
    end

    test "Datetimes" do
      assert to_expression(~D[2022-11-04]) == "'2022-11-04'"
      assert to_expression(~U[2022-11-04 10:40:11.362181Z]) == "'2022-11-04 10:40:11.362181Z'"
      assert to_expression(~N[2022-11-04 10:40:01.256931]) == "'2022-11-04 10:40:01.256931'"
      assert to_expression(~T[10:40:17.657300]) == "'10:40:17.657300'"
    end

    test "Postgrex types" do
      assert to_expression(%INET{address: {127, 0, 0, 1}, netmask: 24}) == "'127.0.0.1/24'"
      assert to_expression(%INET{address: {127, 0, 0, 1}, netmask: nil}) == "'127.0.0.1'"
      assert to_expression(%MACADDR{address: {8, 1, 43, 5, 7, 9}}) == "'08:01:2B:05:07:09'"
      assert to_expression(%Interval{days: 2, secs: 34}) == "'2 days, 34 seconds'"
      assert_raise(RuntimeError, fn -> to_expression(%Lexeme{word: "foo", positions: []}) end)
    end

    test "Geo types" do
      assert to_expression(%Geo.Point{
               coordinates: {44.21587, -87.5947},
               srid: 4326,
               properties: %{}
             }) ==
               ~s|'{"coordinates":[44.21587,-87.5947],"crs":{"properties":{"name":"EPSG:4326"},"type":"name"},"type":"Point"}'|

      assert to_expression(%Geo.Polygon{
               coordinates: [
                 [{2.20, 41.41}, {2.13, 41.41}, {2.13, 41.35}, {2.20, 41.35}, {2.20, 41.41}]
               ],
               srid: nil,
               properties: %{}
             }) ==
               ~s|'{"coordinates":[[[2.2,41.41],[2.13,41.41],[2.13,41.35],[2.2,41.35],[2.2,41.41]]],"type":"Polygon"}'|
    end

    test "Maps" do
      assert to_expression(%{
               "string" => "string",
               "boolean" => true,
               "integer" => 1,
               "array" => [1, 2, 3]
             }) == ~s|'{"array":[1,2,3],"boolean":true,"integer":1,"string":"string"}'|
    end

    test "Tuples" do
      assert to_expression({1, 1.2, "string", "", nil}) == ~s|'(1,1.2,string,"",)'|

      assert to_expression({"'", ~s|"|, ")", "(", ",", "multiple words"}) ==
               ~s|'('',\\",")","(",",",multiple words)'|

      assert to_expression({{<<49, 95, 131>>, "hello", nil}, {nil, [1, 2, 3]}}) ==
               ~s|ROW(ROW(DECODE('MV+D','BASE64'),'hello',NULL),'(,"{1,2,3}")')|
    end

    test "Lists" do
      # Empty
      assert to_expression([]) == "'{}'"

      # Atom
      assert to_expression([true, false, nil]) == "'{true,false,NULL}'"
      assert to_expression([:hello, :world]) == ~s|'{hello,world}'|

      # Numbers
      assert to_expression([1, 2.3, 3]) == "'{1,2.3,3}'"
      assert to_expression([1, 2, 3, nil]) == ~s|'{1,2,3,NULL}'|

      # Strings
      assert to_expression(["abc", "DFG", "NULL", ""]) == ~s|'{abc,DFG,"NULL",""}'|
      assert to_expression(["single quote:'"]) == "'{single quote:''}'"
      assert to_expression(["double quote:\""]) == ~s|'{double quote:\\"}'|
      assert to_expression(["{", "}", ","]) == ~s|'{"{","}",","}'|

      # Datetimes
      assert to_expression([
               ~D[2022-11-04],
               ~U[2022-11-04 10:40:11.362181Z],
               ~N[2022-11-04 10:40:01.256931],
               ~T[10:40:17.657300]
             ]) ==
               "'{2022-11-04,2022-11-04 10:40:11.362181Z,2022-11-04 10:40:01.256931,10:40:17.657300}'"

      # Postgrex types
      assert to_expression([
               %INET{address: {127, 0, 0, 1}, netmask: 24},
               %MACADDR{address: {8, 1, 43, 5, 7, 9}},
               %Interval{secs: 42}
             ]) == "'{127.0.0.1/24,08:01:2B:05:07:09,42 seconds}'"

      # List of lexemes is considered as tsvector
      assert to_expression([
               %Lexeme{word: "Joe's", positions: [{5, :D}]},
               %Lexeme{word: "foo", positions: [{1, :A}, {3, :B}, {2, nil}]},
               %Lexeme{word: "bar", positions: []}
             ]) == "'''Joe''''s'':5 foo:1A,3B,2 bar'"

      # Others
      assert to_expression([[1, 2, 3], [3, 4, 5]]) == "'{{1,2,3},{3,4,5}}'"
      assert to_expression([["a", "b", "c"], ["d", "f", "e"]]) == "'{{a,b,c},{d,f,e}}'"
      assert to_expression([%{}, %{}]) == ~s|'{"{}","{}"}'|
      assert to_expression([{1, "USD"}, {2, "USD"}]) == ~s|'{"(1,USD)","(2,USD)"}'|

      assert to_expression([[<<49, 95, 131>>, <<101, 176, 212>>, nil]]) ==
               "ARRAY[ARRAY[DECODE('MV+D','BASE64'),DECODE('ZbDU','BASE64'),NULL]]"
    end
  end
end
