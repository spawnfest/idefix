defmodule Idefix.UpgradeFunction do
  @moduledoc """
    Module which renames deprecated functions to new versions
    - Enum.chunk -> Enum.chunk_every
    - Enum.filter_map -> Enum.filter |> Enum.map
    - IO.char_data_to_string -> IO.chardata_to_string
    - Regex.regex?/1 -> Kernel.is_struct/2
    - System.stracktrace/0 -> __STACKTRACE__
  """

  def fix({:., meta, [{:__aliases__, b, [:IO]}, :char_data_to_string]}) do
    {:., meta, [{:__aliases__, b, [:IO]}, :chardata_to_string]}
  end

  def fix({:., meta, [{:__aliases__, b, [:Enum]}, :chunk]}) do
    {:., meta, [{:__aliases__, b, [:Enum]}, :chunk_every]}
  end

  def fix({{:., _a, [{:__aliases__, _b, [:Enum]}, :filter_map]}, _c, [enum, filter, mapper]}) do
    quote do
      unquote(enum)
      |> Enum.filter(unquote(filter))
      |> Enum.map(unquote(mapper))
    end
  end

  def fix({{:., meta, [{:__aliases__, _meta2, [:System]}, :stacktrace]}, _meta3, []}) do
    {:__STACKTRACE__, meta, nil}
  end

  # will be included in 1.11
  # def fix({{:., line, [{:__aliases__, _, [:Regex]}, :regex?]}, _, args}) do
  #   {{:., line, [{:__aliases__, line, [:Kernel]}, :is_struct]}, line, args ++ :Regex}
  # end

  def fix(ast) do
    ast
  end
end
