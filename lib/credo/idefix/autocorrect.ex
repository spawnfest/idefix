defmodule Credo.Idefix.Autocorrect do
  use Credo.Execution.Task

  @moduledoc """
  Autocorrects some obvious styling issues example:
    - removing single pipe (a |> IO.inspect)
    - replace deprecated functions
  """

  def call(exec, _opts) do
    # TODO: filter issues for Credo.Check.Readability.SinglePipe only
    issues_map = GenServer.call(exec.issues_pid, :to_map)

    Enum.each(issues_map, fn
      {"examples/single_pipes.ex" = file, _issues} ->
        contents = File.read!(file)
        {:ok, ast} = Code.string_to_quoted(contents)

        nast = Macro.prewalk(ast, &apply_fixes/1)

        result =
          nast
          |> Macro.to_string()
          |> IO.chardata_to_string()

        IO.puts(result)

      # File.write(file, result)
      _ ->
        :noop
    end)

    exec
  end

  def apply_fixes(ast) do
    ast
    |> Idefix.SinglePipe.fix()
    |> Idefix.UpgradeFunction.fix()
  end
end
