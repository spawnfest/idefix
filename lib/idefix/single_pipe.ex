defmodule Idefix.SinglePipe do
  @moduledoc """
    Module which modifies AST to remove single pipes (`a |> IO.inspect`)
  """

  def fix({:|>, _, [{:|>, _, _} | _]} = ast), do: ast

  def fix({:|>, _meta, [first, second]}) do
    {mod, line, args} = second

    nast =
      if args == nil do
        {mod, line, [first]}
      else
        {mod, line, [first | args]}
      end

    nast
  end

  def fix(ast), do: ast
end
