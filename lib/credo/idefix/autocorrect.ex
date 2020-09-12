defmodule Credo.Idefix.Autocorrect do
  use Credo.Execution.Task

  @moduledoc """
  Autocorrects some obvious styling issues example:
    - removing single pipe (a |> IO.inspect)
  """


  def call(exec, _opts) do
    # TODO: filter issues for Credo.Check.Readability.SinglePipe only
    issues_map = GenServer.call(exec.issues_pid, :to_map)

    Enum.each(issues_map, fn
      {"examples/single_pipes.ex" = file, _issues} ->
        contents = File.read!(file)
        {:ok, ast} = Code.string_to_quoted(contents)

        nast = Macro.prewalk(ast, &fix_readability_single_pipe/1)

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

  defp fix_readability_single_pipe({:|>, _, [{:|>, _, _} | _]} = ast), do: ast

  defp fix_readability_single_pipe({:|>, _meta, [first, second]} = ast) do
    IO.inspect(ast, label: "Single pipe detected ", limit: :infinity)
    {mod, line, args} = second

    nast =
      if args == nil do
        {mod, line, [first]}
      else
        {mod, line, [first| args]}
      end

    IO.inspect(nast, label: "Single pipe removed ", limit: :infinity)
    nast
  end

  defp fix_readability_single_pipe(ast), do: ast
end