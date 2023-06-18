defmodule Ash.Atomic do
  defstruct [:attribute, :expr]

  @type t :: %__MODULE__{
          attribute: atom,
          expr: Ash.Expr.t()
        }

  defmacro atomic(attribute, expr) do
    quote do
      require Ash.Expr
      %Ash.Atomic{attribute: unquote(attribute), expr: Ash.Expr.expr(unquote(expr))}
    end
  end

  @doc false
  def schema do
    [
      attribute: [
        type: :atom,
        required: true,
        doc: "The attribute to be set."
      ],
      expr: [
        type: :any,
        required: true,
        doc: "The expression to use to determine the value."
      ]
    ]
  end
end
