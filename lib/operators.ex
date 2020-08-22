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
      alias DreaeQL.Operators
      Operators.binary_operator And
      Operators.binary_operator Or
      Operators.binary_operator NotEquals
      Operators.binary_operator Equals
      Operators.binary_operator GreaterThan
      Operators.binary_operator LessThan
      Operators.binary_operator GreaterThanEquals
      Operators.binary_operator LessThanEquals
    end
  end
end
