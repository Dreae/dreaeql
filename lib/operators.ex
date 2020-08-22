defmodule DreaeQL.Operators do
  defmacro binary_operator(name) do
    quote do
      defmodule DreaeQL.Operators.unquote(name) do
        @type t :: %DreaeQL.Operators.unquote(name){
          left_side: DreaeQL.expression,
          right_side: DreaeQL.expression,
          operator: :binary
        }
        defstruct [:left_side, :right_side, operator: :binary]
      end
    end
  end

  defmacro unary_operator(name) do
    quote do
      defmodule DreaeQL.Operators.unquote(name) do
        @type t :: %DreaeQL.Operators.unquote(name){
          expr: DreaeQL.expression,
          operator: :unary
        }
        defstruct [:expr, operator: :unary]
      end
    end
  end

  defmacro __using__(_params) do
    quote do
      alias DreaeQL.Operators

      @type dreaeql_binary_operator ::
        Operators.And.t
        | Operators.Or.t
        | Operators.NotEquals.t
        | Operators.Equals.t
        | Operators.GreaterThan.t
        | Operators.LessThan.t
        | Operators.GreaterThanEquals.t
        | Operators.LessThanEquals.t
      @type dreaeql_unary_operator :: Operators.Not.t
      @type dreaeql_operator :: dreaeql_binary_operator | dreaeql_unary_operator

      Operators.binary_operator And
      Operators.binary_operator Or
      Operators.binary_operator NotEquals
      Operators.binary_operator Equals
      Operators.binary_operator GreaterThan
      Operators.binary_operator LessThan
      Operators.binary_operator GreaterThanEquals
      Operators.binary_operator LessThanEquals
      Operators.unary_operator Not
    end
  end
end
