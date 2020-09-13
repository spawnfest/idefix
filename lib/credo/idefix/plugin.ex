defmodule Credo.Idefix.Plugin do
  import Credo.Plugin

  def init(exec) do
    exec
    |> append_task(:run_command, Idefix.Credo.Autocorrect)
    |> register_cli_switch(:autocorrect, :boolean, false)
  end
end
