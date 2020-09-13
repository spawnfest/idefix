defmodule Mix.Tasks.Idefix do
  use Mix.Task

  @shortdoc "Task to modify code in examples folder"
  def run(_) do
    Enum.each(File.ls!("examples/"), fn
      file ->
        file = "examples/" <> file
        contents = File.read!(file)
        # transfom code to ast
        {:ok, ast} = Code.string_to_quoted(contents)

        # walk the AST and transform it
        nast = Macro.prewalk(ast, &apply_fixes/1)

        # turn AST back to code
        result =
          nast
          |> Idefix.Macro.to_string()
          |> IO.chardata_to_string()

        File.write(file, result)
        Mix.Tasks.Format.run([file])
    end)
  end

  @spec apply_fixes(Macro.t()) :: Macro.t()
  defp apply_fixes(ast) do
    ast
    |> Idefix.SinglePipe.fix()
    |> Idefix.UpgradeFunction.fix()
  end
end
