defmodule DreaeQL do
  @moduledoc """
  A library for parsing a simple query language into an abstract syntax tree.
  """

  @type ast :: term()

  @doc """
  Parses a string into a DreaeQL AST. Returns a tuple containing the AST
  and any unused tokens, if any.

  ## Examples

    ```
    iex> DreaeQL.parse("foo = 123 and bar = \\"456\\"")
    {%DreaeQL.Operators.And{
      left_side: %DreaeQL.Operators.Equals{
        left_side: %DreaeQL.Terms.Identifier{ident: "foo", term: :ident},
        operator: :binary,
        right_side: %DreaeQL.Terms.LiteralInt{term: :int, value: 123}
      },
      operator: :binary,
      right_side: %DreaeQL.Operators.Equals{
        left_side: %DreaeQL.Terms.Identifier{ident: "bar", term: :ident},
        operator: :binary,
        right_side: %DreaeQL.Terms.LiteralString{term: :string, value: "456"}
      }
    }, []}
    ```

  """
  @spec parse(String.t) :: {ast, list()}
  def parse(string), do: parse_tokens(tokenize(string))

  @doc false
  def tokenize(data) do
    tokenize(data, [])
  end

  defp tokenize(" " <> data, tokens), do: tokenize(data, tokens)
  defp tokenize(<<t::unsigned-8>> <> data, tokens) when t >= ?0 and t <= ?9, do: consume_number(data, <<t::unsigned-8>>, tokens)
  defp tokenize(<<t::unsigned-8>> <> data, tokens) when (t >= ?A and t <= ?Z) or (t >= ?a and t <= ?z), do: consume_identifier(data, <<t::unsigned-8>>, tokens)
  defp tokenize("\"" <> data, tokens), do: consume_string(data, "", tokens)
  defp tokenize("-" <> data, tokens), do: consume_number(data, "-", tokens)
  defp tokenize("(" <> data, tokens), do: tokenize(data, [:open_paren | tokens])
  defp tokenize(")" <> data, tokens), do: tokenize(data, [:close_paren | tokens])
  defp tokenize("=" <> data, tokens), do: tokenize(data, [:equals | tokens])
  defp tokenize("!=" <> data, tokens), do: tokenize(data, [:not_equals | tokens])
  defp tokenize("<" <> data, tokens), do: tokenize(data, [:lt | tokens])
  defp tokenize("<=" <> data, tokens), do: tokenize(data, [:le | tokens])
  defp tokenize(">" <> data, tokens), do: tokenize(data, [:gt | tokens])
  defp tokenize(">=" <> data, tokens), do: tokenize(data, [:ge | tokens])
  defp tokenize("", tokens), do: Enum.reverse(tokens)

  defp consume_number(<<t::unsigned-8>> <> data, token, tokens) when t >= ?0 and t <= ?9, do: consume_number(data, token <> <<t::unsigned-8>>, tokens)
  defp consume_number("_" <> data, token, tokens), do: consume_number(data, token, tokens)
  defp consume_number("." <> data, token, tokens), do: consume_float(data, token <> ".", tokens)
  defp consume_number(data, token, tokens), do: tokenize(data, [finalize_number(token) | tokens])
  defp finalize_number(token) do
    {num, ""} = Integer.parse(token)
    [:literal, :int, num]
  end

  defp consume_float(<<t::unsigned-8>> <> data, token, tokens) when t >= ?0 and t <= ?9, do: consume_float(data, token <> <<t::unsigned-8>>, tokens)
  defp consume_float("_" <> data, token, tokens), do: consume_float(data, token, tokens)
  defp consume_float(data, token, tokens), do: tokenize(data, [finalize_float(token) | tokens])
  defp finalize_float(token) do
    {num, ""} = Float.parse(token)
    [:literal, :float, num]
  end

  defp consume_identifier(<<t::unsigned-8>> <> data, token, tokens) when (t >= ?A and t <= ?Z) or (t >= ?a and t <= ?z) do
    consume_identifier(data, token <> <<t::unsigned-8>>, tokens)
  end
  defp consume_identifier(data, token, tokens), do: tokenize(data, [finalize_identifier(token) | tokens])

  defp consume_string("\"" <> data, buffer, tokens), do: tokenize(data, [[:literal, :string, buffer] | tokens])
  defp consume_string("\\" <> <<c::unsigned-8>> <> data, buffer, tokens), do: consume_string(data, buffer <> <<c::unsigned-8>>, tokens)
  defp consume_string(<<c::unsigned-8>> <> data, buffer, tokens), do: consume_string(data, buffer <> <<c::unsigned-8>>, tokens)

  defp finalize_identifier("and"), do: :and
  defp finalize_identifier("or"), do: :or
  defp finalize_identifier("not"), do: :not
  defp finalize_identifier("true"), do: [:literal, :bool, :true]
  defp finalize_identifier("false"), do: [:literal, :bool, :false]
  defp finalize_identifier(token), do: [:identifier, token]

  defp parse_tokens(tokens) do
    parse_query(tokens)
  end

  use DreaeQL.Operators
  use DreaeQL.Terms

  defp parse_term([[:identifier, _ident] = ident | tokens]), do: {parse_term_ident(ident), tokens}
  defp parse_term([[:literal, _t, _d] = literal | tokens]), do: {parse_term_literal(literal), tokens}
  defp parse_term([:open_paren | tokens]) do
    {term, [:close_paren | tokens]} = parse_expression(tokens, 0)
    {term, tokens}
  end

  defp parse_term_literal([:literal, :int, num]), do: %Terms.LiteralInt{value: num}
  defp parse_term_literal([:literal, :float, num]), do: %Terms.LiteralFloat{value: num}
  defp parse_term_literal([:literal, :string, value]), do: %Terms.LiteralString{value: value}
  defp parse_term_literal([:literal, :bool, :true]), do: %Terms.LiteralBool{value: true}
  defp parse_term_literal([:literal, :bool, :false]), do: %Terms.LiteralBool{value: false}

  defp parse_term_ident([:identifier, ident]), do: %Terms.Identifier{ident: ident}

  # This is effectively a Pratt parser
  defp parse_expression([op | tokens] = token_stream, min_bp) do
    {lhs, tokens} = case operator_precedence(op) do
      {0, r_bp} ->
        {rhs, tokens} = parse_expression(tokens, r_bp)
        {finalize_operator(op, rhs), tokens}
      _ -> parse_term(token_stream)
    end

    parse_expression(lhs, tokens, min_bp)
  end

  defp parse_expression(lhs, [op | tokens] = token_stream, min_bp) do
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
  defp parse_expression(lhs, [], _), do: {lhs, []}

  defp operator_precedence(:and), do: {1, 2}
  defp operator_precedence(:or), do: {1, 2}
  defp operator_precedence(:equals), do: {4, 3}
  defp operator_precedence(:not_equals), do: {4, 3}
  defp operator_precedence(:lt), do: {4, 3}
  defp operator_precedence(:gt), do: {4, 3}
  defp operator_precedence(:le), do: {4, 3}
  defp operator_precedence(:ge), do: {4, 3}
  defp operator_precedence(:not), do: {0, 3}
  defp operator_precedence(_), do: nil

  defp finalize_operator(:equals, lhs, rhs), do: %Operators.Equals{left_side: lhs, right_side: rhs}
  defp finalize_operator(:not_equals, lhs, rhs), do: %Operators.NotEquals{left_side: lhs, right_side: rhs}
  defp finalize_operator(:gt, lhs, rhs), do: %Operators.GreaterThan{left_side: lhs, right_side: rhs}
  defp finalize_operator(:ge, lhs, rhs), do: %Operators.GreaterThanEquals{left_side: lhs, right_side: rhs}
  defp finalize_operator(:lt, lhs, rhs), do: %Operators.LessThan{left_side: lhs, right_side: rhs}
  defp finalize_operator(:le, lhs, rhs), do: %Operators.LessThanEquals{left_side: lhs, right_side: rhs}
  defp finalize_operator(:and, lhs, rhs), do: %Operators.And{left_side: lhs, right_side: rhs}
  defp finalize_operator(:or, lhs, rhs), do: %Operators.Or{left_side: lhs, right_side: rhs}
  defp finalize_operator(:not, rhs), do: %Operators.Not{expr: rhs}

  defp parse_query(tokens) do
    parse_expression(tokens, 0)
  end
end
