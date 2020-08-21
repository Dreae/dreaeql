defmodule DreaeQL do
  @moduledoc """
  Documentation for `Dreaeql`.
  """

  alias DreaeQL.{Terms, Expressions}

  def parse(string), do: parse_tokens(tokenize(string))

  def tokenize(data) do
    tokenize(data, [])
  end

  def tokenize("=" <> data, tokens), do: tokenize(data, [:equals | tokens])
  def tokenize(" " <> data, tokens), do: tokenize(data, tokens)
  def tokenize(<<t::unsigned-8>> <> data, tokens) when t >= ?0 and t <= ?9, do: consume_number(data, <<t::unsigned-8>>, tokens)
  def tokenize(<<t::unsigned-8>> <> data, tokens) when (t >= ?A and t <= ?Z) or (t >= ?a and t <= ?z), do: consume_identifier(data, <<t::unsigned-8>>, tokens)
  def tokenize("\"" <> data, tokens), do: consume_string(data, "", tokens)
  def tokenize("-" <> data, tokens), do: consume_number(data, "-", tokens)
  def tokenize("(" <> data, tokens), do: tokenize(data, [:open_paren | tokens])
  def tokenize(")" <> data, tokens), do: tokenize(data, [:close_paren | tokens])
  def tokenize("!" <> data, tokens), do: tokenize(data, [:bang | tokens])
  def tokenize("", tokens), do: Enum.reverse(tokens)

  def consume_number(<<t::unsigned-8>> <> data, token, tokens) when t >= ?0 and t <= ?9, do: consume_number(data, token <> <<t::unsigned-8>>, tokens)
  def consume_number("_" <> data, token, tokens), do: consume_number(data, token, tokens)
  def consume_number("." <> data, token, tokens), do: consume_float(data, token <> ".", tokens)
  def consume_number(" " <> data, token, tokens), do: tokenize(data, [finalize_number(token) | tokens])
  def consume_number(")" <> data, token, tokens), do: tokenize(")" <> data, [finalize_number(token) | tokens])
  def consume_number("", token, tokens), do: tokenize("", [finalize_number(token) | tokens])
  def finalize_number(token) do
    {num, ""} = Integer.parse(token)
    [:literal, :int, num]
  end

  def consume_float(<<t::unsigned-8>> <> data, token, tokens) when t >= ?0 and t <= ?9, do: consume_float(data, token <> <<t::unsigned-8>>, tokens)
  def consume_float("_" <> data, token, tokens), do: consume_float(data, token, tokens)
  def consume_float(" " <> data, token, tokens), do: tokenize(data, [finalize_float(token) | tokens])
  def consume_float(")" <> data, token, tokens), do: tokenize(")" <> data, [finalize_float(token) | tokens])
  def consume_float("", token, tokens), do: tokenize("", [finalize_float(token) | tokens])
  def finalize_float(token) do
    {num, ""} = Float.parse(token)
    [:literal, :float, num]
  end

  def consume_identifier(<<t::unsigned-8>> <> data, token, tokens) when (t >= ?A and t <= ?Z) or (t >= ?a and t <= ?z) do
    consume_identifier(data, token <> <<t::unsigned-8>>, tokens)
  end
  def consume_identifier(" " <> data, token, tokens), do: tokenize(data, [finalize_identifier(token) | tokens])
  def consume_identifier(")" <> data, token, tokens), do: tokenize(")" <> data, [finalize_identifier(token) | tokens])
  def consume_identifier("", token, tokens), do: tokenize("", [finalize_identifier(token) | tokens])

  def consume_string("", buffer, tokens), do: tokenize("", [[:literal, :string, buffer] | tokens])
  def consume_string("\"" <> data, buffer, tokens), do: tokenize(data, [[:literal, :string, buffer] | tokens])
  def consume_string("\\" <> <<c::unsigned-8>> <> data, buffer, tokens), do: consume_string(data, buffer <> <<c::unsigned-8>>, tokens)
  def consume_string(<<c::unsigned-8>> <> data, buffer, tokens), do: consume_string(data, buffer <> <<c::unsigned-8>>, tokens)

  def finalize_identifier("and"), do: :and
  def finalize_identifier("or"), do: :or
  def finalize_identifier("true"), do: [:literal, :bool, :true]
  def finalize_identifier("false"), do: [:literal, :bool, :false]
  def finalize_identifier(token), do: [:identifier, token]

  def parse_tokens(tokens) do
    parse_query(tokens)
  end

  def parse_term([[:identifier, _ident] = ident | tokens]), do: {parse_term_ident(ident), tokens}
  def parse_term([[:literal, _t, _d] = literal | tokens]), do: {parse_term_literal(literal), tokens}
  def parse_term([:open_paren | tokens]) do
    {sub_expr, [:close_paren | tokens]} = Enum.split_while(tokens, &(&1 != :close_paren))
    {expr, []} = parse_expression(sub_expr)
    {expr, tokens}
  end

  def parse_term_literal([:literal, :int, num]), do: %Terms.LiteralInt{value: num}
  def parse_term_literal([:literal, :float, num]), do: %Terms.LiteralFloat{value: num}
  def parse_term_literal([:literal, :string, value]), do: %Terms.LiteralString{value: value}
  def parse_term_literal([:literal, :bool, :true]), do: %Terms.LiteralBool{value: true}
  def parse_term_literal([:literal, :bool, :false]), do: %Terms.LiteralBool{value: false}

  def parse_term_ident([:identifier, ident]), do: %Terms.Identifier{ident: ident}

  def parse_expression(tokens) do
    {term, tokens} = parse_term(tokens)
    parse_expression(term, tokens)
  end

  def parse_expression(left_side, [:and | tokens]) do
    {right_side, tokens} = parse_expression(tokens)
    {%Expressions.And{left_side: left_side, right_side: right_side}, tokens}
  end

  def parse_expression(left_side, [:or | tokens]) do
    {right_side, tokens} = parse_expression(tokens)
    {%Expressions.Or{left_side: left_side, right_side: right_side}, tokens}
  end

  def parse_expression(left_side, [:equals | tokens]) do
    {right_side, tokens} = parse_term(tokens)
    parse_expression(%Expressions.Equals{left_side: left_side, right_side: right_side}, tokens)
  end

  def parse_expression(left_side, [:bang, :equals | tokens]) do
    {right_side, tokens} = parse_term(tokens)
    parse_expression(%Expressions.NotEquals{left_side: left_side, right_side: right_side}, tokens)
  end

  def parse_expression(%Terms.Identifier{} = ident, tokens), do: {ident, tokens}
  def parse_expression(%Terms.LiteralInt{} = ident, tokens), do: {ident, tokens}
  def parse_expression(%Terms.LiteralFloat{} = ident, tokens), do: {ident, tokens}
  def parse_expression(%Terms.LiteralString{} = ident, tokens), do: {ident, tokens}
  def parse_expression(%Terms.LiteralBool{} = ident, tokens), do: {ident, tokens}
  def parse_expression(expr, []), do: {expr, []}


  def parse_query(tokens) do
    parse_expression(tokens)
  end
end
