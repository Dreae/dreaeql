defmodule DreaeQL do
  @moduledoc """
  Documentation for `Dreaeql`.
  """

  alias DreaeQL.{Terms, Operators}

  def parse(string), do: parse_tokens(tokenize(string))

  def tokenize(data) do
    tokenize(data, [])
  end

  def tokenize(" " <> data, tokens), do: tokenize(data, tokens)
  def tokenize(<<t::unsigned-8>> <> data, tokens) when t >= ?0 and t <= ?9, do: consume_number(data, <<t::unsigned-8>>, tokens)
  def tokenize(<<t::unsigned-8>> <> data, tokens) when (t >= ?A and t <= ?Z) or (t >= ?a and t <= ?z), do: consume_identifier(data, <<t::unsigned-8>>, tokens)
  def tokenize("\"" <> data, tokens), do: consume_string(data, "", tokens)
  def tokenize("-" <> data, tokens), do: consume_number(data, "-", tokens)
  def tokenize("(" <> data, tokens), do: tokenize(data, [:open_paren | tokens])
  def tokenize(")" <> data, tokens), do: tokenize(data, [:close_paren | tokens])
  def tokenize("=" <> data, tokens), do: tokenize(data, [:equals | tokens])
  def tokenize("!=" <> data, tokens), do: tokenize(data, [:not_equals | tokens])
  def tokenize("<" <> data, tokens), do: tokenize(data, [:lt | tokens])
  def tokenize("<=" <> data, tokens), do: tokenize(data, [:le | tokens])
  def tokenize(">" <> data, tokens), do: tokenize(data, [:gt | tokens])
  def tokenize(">=" <> data, tokens), do: tokenize(data, [:ge | tokens])
  def tokenize("", tokens), do: Enum.reverse(tokens)

  def consume_number(<<t::unsigned-8>> <> data, token, tokens) when t >= ?0 and t <= ?9, do: consume_number(data, token <> <<t::unsigned-8>>, tokens)
  def consume_number("_" <> data, token, tokens), do: consume_number(data, token, tokens)
  def consume_number("." <> data, token, tokens), do: consume_float(data, token <> ".", tokens)
  def consume_number(" " <> data, token, tokens), do: tokenize(data, [finalize_number(token) | tokens])
  def consume_number(")" <> _data = buffer, token, tokens), do: tokenize(buffer, [finalize_number(token) | tokens])
  def consume_number("", token, tokens), do: tokenize("", [finalize_number(token) | tokens])
  def finalize_number(token) do
    {num, ""} = Integer.parse(token)
    [:literal, :int, num]
  end

  def consume_float(<<t::unsigned-8>> <> data, token, tokens) when t >= ?0 and t <= ?9, do: consume_float(data, token <> <<t::unsigned-8>>, tokens)
  def consume_float("_" <> data, token, tokens), do: consume_float(data, token, tokens)
  def consume_float(" " <> data, token, tokens), do: tokenize(data, [finalize_float(token) | tokens])
  def consume_float(")" <> _data = buffer, token, tokens), do: tokenize(buffer, [finalize_float(token) | tokens])
  def consume_float("", token, tokens), do: tokenize("", [finalize_float(token) | tokens])
  def finalize_float(token) do
    {num, ""} = Float.parse(token)
    [:literal, :float, num]
  end

  def consume_identifier(<<t::unsigned-8>> <> data, token, tokens) when (t >= ?A and t <= ?Z) or (t >= ?a and t <= ?z) do
    consume_identifier(data, token <> <<t::unsigned-8>>, tokens)
  end
  def consume_identifier(" " <> data, token, tokens), do: tokenize(data, [finalize_identifier(token) | tokens])
  def consume_identifier(")" <> _data = buffer, token, tokens), do: tokenize(buffer, [finalize_identifier(token) | tokens])
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

  use DreaeQL.Operators
  use DreaeQL.Terms

  def parse_term([[:identifier, _ident] = ident | tokens]), do: {parse_term_ident(ident), tokens}
  def parse_term([[:literal, _t, _d] = literal | tokens]), do: {parse_term_literal(literal), tokens}
  def parse_term([:open_paren | tokens]) do
    {term, [:close_paren | tokens]} = parse_expression(tokens, 0)
    {term, tokens}
  end

  def parse_term_literal([:literal, :int, num]), do: %Terms.LiteralInt{value: num}
  def parse_term_literal([:literal, :float, num]), do: %Terms.LiteralFloat{value: num}
  def parse_term_literal([:literal, :string, value]), do: %Terms.LiteralString{value: value}
  def parse_term_literal([:literal, :bool, :true]), do: %Terms.LiteralBool{value: true}
  def parse_term_literal([:literal, :bool, :false]), do: %Terms.LiteralBool{value: false}

  def parse_term_ident([:identifier, ident]), do: %Terms.Identifier{ident: ident}

  # This is effectively a Pratt parser
  def parse_expression(tokens, min_bp) do
    {lhs, tokens} = parse_term(tokens)
    parse_expression(lhs, tokens, min_bp)
  end

  def parse_expression(lhs, [op | tokens] = token_stream, min_bp) do
    case operator_precedence(op) do
      {l_bp, r_bp} ->
        if l_bp < min_bp do
          {lhs, token_stream}
        else
          {rhs, tokens} = parse_expression(tokens, r_bp)
          parse_expression(finalize_operator(op, lhs, rhs), tokens, min_bp)
        end
      _ -> {lhs, token_stream}
    end
  end
  def parse_expression(lhs, [], _), do: {lhs, []}

  def operator_precedence(:and), do: {2, 1}
  def operator_precedence(:or), do: {2, 1}
  def operator_precedence(:equals), do: {8, 7}
  def operator_precedence(:not_equals), do: {8, 7}
  def operator_precedence(:lt), do: {8, 7}
  def operator_precedence(:gt), do: {8, 7}
  def operator_precedence(:le), do: {8, 7}
  def operator_precedence(:ge), do: {8, 7}
  def operator_precedence(_), do: nil

  def finalize_operator(:equals, lhs, rhs), do: %Operators.Equals{left_side: lhs, right_side: rhs}
  def finalize_operator(:not_equals, lhs, rhs), do: %Operators.NotEquals{left_side: lhs, right_side: rhs}
  def finalize_operator(:gt, lhs, rhs), do: %Operators.GreaterThan{left_side: lhs, right_side: rhs}
  def finalize_operator(:ge, lhs, rhs), do: %Operators.GreaterThanEquals{left_side: lhs, right_side: rhs}
  def finalize_operator(:lt, lhs, rhs), do: %Operators.LessThan{left_side: lhs, right_side: rhs}
  def finalize_operator(:le, lhs, rhs), do: %Operators.LessThanEquals{left_side: lhs, right_side: rhs}
  def finalize_operator(:and, lhs, rhs), do: %Operators.And{left_side: lhs, right_side: rhs}
  def finalize_operator(:or, lhs, rhs), do: %Operators.Or{left_side: lhs, right_side: rhs}

  def parse_query(tokens) do
    parse_expression(tokens, 0)
  end
end
