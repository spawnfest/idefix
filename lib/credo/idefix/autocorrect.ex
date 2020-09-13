defmodule Credo.Idefix.Autocorrect do
  use Credo.Execution.Task

  @moduledoc """
  Autocorrects some obvious styling issues example:
    - removing single pipe (a |> IO.inspect)
    - replace deprecated functions
  """
  @spec call(Credo.Execution.t(), Keyword.t()) :: Credo.Execution.t()
  def call(exec, _opts) do
    # TODO: filter issues for Credo.Check.Readability.SinglePipe or other interests only
    issues_map = GenServer.call(exec.issues_pid, :to_map)

    Enum.each(issues_map, fn
      {"examples/single_pipes.ex" = file, _issues} ->
        contents = File.read!(file)
        # transfom code to ast
        {:ok, ast} = Code.string_to_quoted(contents)

        # walk the AST and transform it
        nast = Macro.postwalk(ast, &apply_fixes/1)

        # turn AST back to code
        result =
          nast
          |> Idefix.Macro.to_string()
          |> IO.chardata_to_string()

        IO.puts(result)

      # File.write(file, result)
      _ ->
        :noop
    end)

    exec
  end

  @spec apply_fixes(Macro.t()) :: Macro.t()
  def apply_fixes(ast) do
    ast
    |> Idefix.SinglePipe.fix()
    |> Idefix.UpgradeFunction.fix()
  end
end
