defmodule DreaeQLTest do
  use ExUnit.Case
  doctest DreaeQL

  test "Tokenizes simple strings" do
    assert DreaeQL.tokenize("foo = 123") == [[:identifier, "foo"], :equals, [:literal, :int, 123]]
  end

  test "Tokenizes parenthetical expressions" do
    assert DreaeQL.tokenize("(foo = 123)") == [:open_paren, [:identifier, "foo"], :equals, [:literal, :int, 123], :close_paren]
  end

  test "Tokenizes string literals" do
    assert DreaeQL.tokenize("foo != \"123\"") == [[:identifier, "foo"], :not_equals, [:literal, :string, "123"]]
    assert DreaeQL.tokenize("\"foo\\\"\"") == [[:literal, :string, "foo\""]]
  end

  test "Tokenizes float literals" do
    assert DreaeQL.tokenize("foo != 123.4565") == [[:identifier, "foo"], :not_equals, [:literal, :float, 123.4565]]
  end
end
