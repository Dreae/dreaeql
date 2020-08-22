defmodule DreaeQL.Operators do
  defmacro binary_operator(name) do
    quote do
      defmodule DreaeQL.Operators.unquote(name) do
        defstruct [:left_side, :right_side, operator: :binary]
      end
    end
  end

  defmacro __using__(_params) do
    quote do
      DreaeQL.Operators.binary_operator And
      DreaeQL.Operators.binary_operator Or
      DreaeQL.Operators.binary_operator NotEquals
      DreaeQL.Operators.binary_operator Equals
      DreaeQL.Operators.binary_operator GreaterThan
      DreaeQL.Operators.binary_operator LessThan
      DreaeQL.Operators.binary_operator GreaterThanEquals
      DreaeQL.Operators.binary_operator LessThanEquals
    end
  end
end
