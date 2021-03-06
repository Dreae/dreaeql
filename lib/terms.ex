defmodule DreaeQL.Terms do
  defmacro term(name, type, params) do
    quote do
      defmodule DreaeQL.Terms.unquote(name) do
        @type t :: %DreaeQL.Terms.unquote(name){term: unquote(type)}
        defstruct [term: unquote(type)] ++ unquote(params)
      end
    end
  end

  defmacro literal(name, type) do
    quote do
      DreaeQL.Terms.term(unquote(name), unquote(type), [:value])
    end
  end

  defmacro __using__(_params) do
    quote do
      alias DreaeQL.Terms
      Terms.literal LiteralInt, :int
      Terms.literal LiteralFloat, :float
      Terms.literal LiteralBool, :bool
      Terms.literal LiteralString, :string
      Terms.term Identifier, :ident, [:ident]

      @type dreaeql_term ::
        Terms.Identifier.t
        | Terms.LiteralBool.t
        | Terms.LiteralInt.t
        | Terms.LiteralFloat.t
        | Terms.LiteralString.t
    end
  end
end
