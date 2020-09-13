defmodule DeprecatedFunctions do
  @moduledoc "Example of deprecated (or soft-deprecated) functions"

  def chunky_bacon(list) do
    Enum.chunk(list, 2)
  end

  def write_once(regex) do
    Regex.regex?(regex)
  end

  def output_stacktrace() do
    IO.inspect(System.stacktrace(), label: "Current stacktrace ")
  end

  def old_filter_map() do
    Enum.filter_map([1, 2, 3], fn x -> rem(x, 2) == 0 end, &(&1 * 2))
  end
end
