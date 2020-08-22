defmodule DreaeQL.Terms do
  defmacro term(name, type, params) do
    quote do
      defmodule DreaeQL.Terms.unquote(name) do
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
      DreaeQL.Terms.literal LiteralInt, :int
      DreaeQL.Terms.literal LiteralFloat, :float
      DreaeQL.Terms.literal LiteralBool, :bool
      DreaeQL.Terms.literal LiteralString, :string
      DreaeQL.Terms.term Identifier, :ident, [:ident]
    end
  end
end
