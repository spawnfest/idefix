defmodule Idefix.Macro do
  @moduledoc """
  A modified version of Elixirs Macro module in order to have
  Macro.to_string which works to our liking. Elixirs produces parentheses around
  macro calls as well, not just function heads and functions calls. Example:

    Elixirs:
    defmodule(Test) do
      def(hello(name)) do
        IO.puts("Hello " <> name)
      end
    end

    Ours:
    defmodule Test do
      def hello(name) do
        IO.puts("Hello " <> name)
      end
    end

  """

  import Kernel, except: [to_string: 1]

  alias Code.Identifier

  @locals_without_parens [
    # Special forms
    alias: 1,
    alias: 2,
    case: 2,
    cond: 1,
    for: :*,
    import: 1,
    import: 2,
    quote: 1,
    quote: 2,
    receive: 1,
    require: 1,
    require: 2,
    try: 1,
    with: :*,

    # Kernel
    def: 1,
    def: 2,
    defp: 1,
    defp: 2,
    defguard: 1,
    defguardp: 1,
    defmacro: 1,
    defmacro: 2,
    defmacrop: 1,
    defmacrop: 2,
    defmodule: 2,
    defdelegate: 2,
    defexception: 1,
    defoverridable: 1,
    defstruct: 1,
    destructure: 2,
    raise: 1,
    raise: 2,
    reraise: 2,
    reraise: 3,
    if: 2,
    unless: 2,
    use: 1,
    use: 2,

    # Stdlib,
    defrecord: 2,
    defrecord: 3,
    defrecordp: 2,
    defrecordp: 3,

    # Testing
    assert: 1,
    assert: 2,
    assert_in_delta: 3,
    assert_in_delta: 4,
    assert_raise: 2,
    assert_raise: 3,
    assert_receive: 1,
    assert_receive: 2,
    assert_receive: 3,
    assert_received: 1,
    assert_received: 2,
    doctest: 1,
    doctest: 2,
    refute: 1,
    refute: 2,
    refute_in_delta: 3,
    refute_in_delta: 4,
    refute_receive: 1,
    refute_receive: 2,
    refute_receive: 3,
    refute_received: 1,
    refute_received: 2,
    setup: 1,
    setup: 2,
    setup_all: 1,
    setup_all: 2,
    test: 1,
    test: 2,

    # Mix config
    config: 2,
    config: 3,
    import_config: 1
  ]

  def unpipe(expr) do
    :lists.reverse(unpipe(expr, []))
  end

  defp unpipe({:|>, _, [left, right]}, acc) do
    unpipe(right, unpipe(left, acc))
  end

  defp unpipe(other, acc) do
    [{other, 0} | acc]
  end

  def pipe(expr, call_args, position)

  def pipe(expr, {:&, _, _} = call_args, _integer) do
    raise ArgumentError, bad_pipe(expr, call_args)
  end

  def pipe(expr, {tuple_or_map, _, _} = call_args, _integer) when tuple_or_map in [:{}, :%{}] do
    raise ArgumentError, bad_pipe(expr, call_args)
  end

  def pipe(expr, {:__aliases__, _, _} = call_args, _integer) do
    raise ArgumentError, bad_pipe(expr, call_args)
  end

  def pipe(expr, {:<<>>, _, _} = call_args, _integer) do
    raise ArgumentError, bad_pipe(expr, call_args)
  end

  def pipe(expr, {unquote, _, []}, _integer) when unquote in [:unquote, :unquote_splicing] do
    raise ArgumentError,
          "cannot pipe #{to_string(expr)} into the special form #{unquote}/1 " <>
            "since #{unquote}/1 is used to build the Elixir AST itself"
  end

  def pipe(expr, {:fn, _, _}, _integer) do
    raise ArgumentError,
          "cannot pipe #{to_string(expr)} into an anonymous function without" <>
            " calling the function; use something like (fn ... end).() or" <>
            " define the anonymous function as a regular private function"
  end

  def pipe(expr, {call, line, atom}, integer) when is_atom(atom) do
    {call, line, List.insert_at([], integer, expr)}
  end

  def pipe(_expr, {op, _line, [arg]}, _integer) when op == :+ or op == :- do
    raise ArgumentError,
          "piping into a unary operator is not supported, please use the qualified name: " <>
            "Kernel.#{op}(#{to_string(arg)}), instead of #{op}#{to_string(arg)}"
  end

  def pipe(expr, {op, line, args} = op_args, integer) when is_list(args) do
    cond do
      is_atom(op) and Identifier.unary_op(op) != :error ->
        raise ArgumentError,
              "cannot pipe #{to_string(expr)} into #{to_string(op_args)}, " <>
                "the #{to_string(op)} operator can only take one argument"

      is_atom(op) and Identifier.binary_op(op) != :error ->
        raise ArgumentError,
              "cannot pipe #{to_string(expr)} into #{to_string(op_args)}, " <>
                "the #{to_string(op)} operator can only take two arguments"

      true ->
        {op, line, List.insert_at(args, integer, expr)}
    end
  end

  def pipe(expr, call_args, _integer) do
    raise ArgumentError, bad_pipe(expr, call_args)
  end

  defp bad_pipe(expr, call_args) do
    "cannot pipe #{to_string(expr)} into #{to_string(call_args)}, " <>
      "can only pipe into local calls foo(), remote calls Foo.bar() or anonymous function calls foo.()"
  end

  def update_meta(quoted, fun)

  def update_meta({left, meta, right}, fun) when is_list(meta) do
    {left, fun.(meta), right}
  end

  def update_meta(other, _fun) do
    other
  end

  def generate_arguments(amount, context)

  def generate_arguments(0, context) when is_atom(context), do: []

  def generate_arguments(amount, context)
      when is_integer(amount) and amount > 0 and is_atom(context) do
    for id <- 1..amount, do: var(String.to_atom("arg" <> Integer.to_string(id)), context)
  end

  def var(var, context) when is_atom(var) and is_atom(context) do
    {var, [], context}
  end

  def traverse(ast, acc, pre, post) when is_function(pre, 2) and is_function(post, 2) do
    {ast, acc} = pre.(ast, acc)
    do_traverse(ast, acc, pre, post)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) when is_atom(form) do
    {args, acc} = do_traverse_args(args, acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) do
    {form, acc} = pre.(form, acc)
    {form, acc} = do_traverse(form, acc, pre, post)
    {args, acc} = do_traverse_args(args, acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({left, right}, acc, pre, post) do
    {left, acc} = pre.(left, acc)
    {left, acc} = do_traverse(left, acc, pre, post)
    {right, acc} = pre.(right, acc)
    {right, acc} = do_traverse(right, acc, pre, post)
    post.({left, right}, acc)
  end

  defp do_traverse(list, acc, pre, post) when is_list(list) do
    {list, acc} = do_traverse_args(list, acc, pre, post)
    post.(list, acc)
  end

  defp do_traverse(x, acc, _pre, post) do
    post.(x, acc)
  end

  defp do_traverse_args(args, acc, _pre, _post) when is_atom(args) do
    {args, acc}
  end

  defp do_traverse_args(args, acc, pre, post) when is_list(args) do
    Enum.map_reduce(args, acc, fn x, acc ->
      {x, acc} = pre.(x, acc)
      do_traverse(x, acc, pre, post)
    end)
  end

  def prewalk(ast, fun) when is_function(fun, 1) do
    elem(prewalk(ast, nil, fn x, nil -> {fun.(x), nil} end), 0)
  end

  def prewalk(ast, acc, fun) when is_function(fun, 2) do
    traverse(ast, acc, fun, fn x, a -> {x, a} end)
  end

  def postwalk(ast, fun) when is_function(fun, 1) do
    elem(postwalk(ast, nil, fn x, nil -> {fun.(x), nil} end), 0)
  end

  def postwalk(ast, acc, fun) when is_function(fun, 2) do
    traverse(ast, acc, fn x, a -> {x, a} end, fun)
  end

  def decompose_call(ast)

  def decompose_call({{:., _, [remote, function]}, _, args})
      when is_tuple(remote) or is_atom(remote),
      do: {remote, function, args}

  def decompose_call({name, _, args}) when is_atom(name) and is_atom(args), do: {name, []}

  def decompose_call({name, _, args}) when is_atom(name) and is_list(args), do: {name, args}

  def decompose_call(_), do: :error

  def escape(expr, opts \\ []) do
    unquote = Keyword.get(opts, :unquote, false)
    kind = if Keyword.get(opts, :prune_metadata, false), do: :prune_metadata, else: :default
    :elixir_quote.escape(expr, kind, unquote)
  end

  def struct!(module, env) when is_atom(module) do
    if module == env.module do
      Module.get_attribute(module, :struct)
    end || :elixir_map.load_struct([line: env.line], module, [], env)
  end

  def validate(expr) do
    find_invalid(expr) || :ok
  end

  defp find_invalid({left, right}), do: find_invalid(left) || find_invalid(right)

  defp find_invalid({left, meta, right})
       when is_list(meta) and (is_atom(right) or is_list(right)),
       do: find_invalid(left) || find_invalid(right)

  defp find_invalid(list) when is_list(list), do: Enum.find_value(list, &find_invalid/1)

  defp find_invalid(pid) when is_pid(pid), do: nil
  defp find_invalid(atom) when is_atom(atom), do: nil
  defp find_invalid(num) when is_number(num), do: nil
  defp find_invalid(bin) when is_binary(bin), do: nil

  defp find_invalid(fun) when is_function(fun) do
    unless Function.info(fun, :env) == {:env, []} and
             Function.info(fun, :type) == {:type, :external} do
      {:error, fun}
    end
  end

  defp find_invalid(other), do: {:error, other}

  def unescape_string(chars) do
    :elixir_interpolation.unescape_chars(chars)
  end

  def unescape_string(chars, map) do
    :elixir_interpolation.unescape_chars(chars, map)
  end

  @doc false
  @deprecated "Traverse over the arguments using Enum.map/2 instead"
  def unescape_tokens(tokens) do
    case :elixir_interpolation.unescape_tokens(tokens) do
      {:ok, unescaped_tokens} -> unescaped_tokens
      {:error, reason} -> raise ArgumentError, to_string(reason)
    end
  end

  @doc false
  @deprecated "Traverse over the arguments using Enum.map/2 instead"
  def unescape_tokens(tokens, map) do
    case :elixir_interpolation.unescape_tokens(tokens, map) do
      {:ok, unescaped_tokens} -> unescaped_tokens
      {:error, reason} -> raise ArgumentError, to_string(reason)
    end
  end

  def to_string(tree, fun \\ fn _ast, string -> string end)

  def to_string({var, _, context} = ast, fun) when is_atom(var) and is_atom(context) do
    fun.(ast, Atom.to_string(var))
  end

  def to_string({:__aliases__, _, refs} = ast, fun) do
    fun.(ast, Enum.map_join(refs, ".", &call_to_string(&1, fun)))
  end

  def to_string({:__block__, _, [expr]} = ast, fun) do
    fun.(ast, to_string(expr, fun))
  end

  def to_string({:__block__, _, _} = ast, fun) do
    block = adjust_new_lines(block_to_string(ast, fun), "\n  ")
    fun.(ast, "(\n  " <> block <> "\n)")
  end

  def to_string({:<<>>, _, parts} = ast, fun) do
    if interpolated?(ast) do
      fun.(ast, interpolate(ast, fun))
    else
      result =
        Enum.map_join(parts, ", ", fn part ->
          str = bitpart_to_string(part, fun)

          if :binary.first(str) == ?< or :binary.last(str) == ?> do
            "(" <> str <> ")"
          else
            str
          end
        end)

      fun.(ast, "<<" <> result <> ">>")
    end
  end

  def to_string({:{}, _, args} = ast, fun) do
    tuple = "{" <> Enum.map_join(args, ", ", &to_string(&1, fun)) <> "}"
    fun.(ast, tuple)
  end

  def to_string({:%{}, _, args} = ast, fun) do
    map = "%{" <> map_to_string(args, fun) <> "}"
    fun.(ast, map)
  end

  def to_string({:%, _, [struct_name, map]} = ast, fun) do
    {:%{}, _, args} = map
    struct = "%" <> to_string(struct_name, fun) <> "{" <> map_to_string(args, fun) <> "}"
    fun.(ast, struct)
  end

  def to_string({:fn, _, [{:->, _, [_, tuple]}] = arrow} = ast, fun)
      when not is_tuple(tuple) or elem(tuple, 0) != :__block__ do
    fun.(ast, "fn " <> arrow_to_string(arrow, fun) <> " end")
  end

  def to_string({:fn, _, [{:->, _, _}] = block} = ast, fun) do
    fun.(ast, "fn " <> block_to_string(block, fun) <> "\nend")
  end

  def to_string({:fn, _, block} = ast, fun) do
    block = adjust_new_lines(block_to_string(block, fun), "\n  ")
    fun.(ast, "fn\n  " <> block <> "\nend")
  end

  def to_string([{:->, _, _} | _] = ast, fun) do
    fun.(ast, "(" <> arrow_to_string(ast, fun, true) <> ")")
  end

  def to_string({:when, _, [left, right]} = ast, fun) do
    right =
      if right != [] and Keyword.keyword?(right) do
        kw_list_to_string(right, fun)
      else
        fun.(ast, op_to_string(right, fun, :when, :right))
      end

    fun.(ast, op_to_string(left, fun, :when, :left) <> " when " <> right)
  end

  def to_string({:when, _, args} = ast, fun) do
    {left, right} = split_last(args)

    result =
      "(" <> Enum.map_join(left, ", ", &to_string(&1, fun)) <> ") when " <> to_string(right, fun)

    fun.(ast, result)
  end

  def to_string({:&, _, [{:/, _, [{name, _, ctx}, arity]}]} = ast, fun)
      when is_atom(name) and is_atom(ctx) and is_integer(arity) do
    result = "&" <> Atom.to_string(name) <> "/" <> to_string(arity, fun)
    fun.(ast, result)
  end

  def to_string({:&, _, [{:/, _, [{{:., _, [mod, name]}, _, []}, arity]}]} = ast, fun)
      when is_atom(name) and is_integer(arity) do
    result =
      "&" <> to_string(mod, fun) <> "." <> Atom.to_string(name) <> "/" <> to_string(arity, fun)

    fun.(ast, result)
  end

  def to_string({:&, _, [arg]} = ast, fun) when not is_integer(arg) do
    fun.(ast, "&(" <> to_string(arg, fun) <> ")")
  end

  def to_string({:not, _, [{:in, _, [left, right]}]} = ast, fun) do
    fun.(ast, to_string(left, fun) <> " not in " <> to_string(right, fun))
  end

  def to_string({{:., _, [Access, :get]}, _, [left, right]} = ast, fun) do
    if op_expr?(left) do
      fun.(ast, "(" <> to_string(left, fun) <> ")" <> to_string([right], fun))
    else
      fun.(ast, to_string(left, fun) <> to_string([right], fun))
    end
  end

  def to_string({{:., _, [left, :{}]}, _, args} = ast, fun) do
    fun.(ast, to_string(left, fun) <> ".{" <> args_to_string(args, fun) <> "}")
  end

  def to_string({{:., _, [left, _]} = target, meta, []} = ast, fun) do
    to_string = call_to_string(target, fun)

    if is_tuple(left) && meta[:no_parens] do
      fun.(ast, to_string)
    else
      fun.(ast, to_string <> "()")
    end
  end

  def to_string({target, _, args} = ast, fun) when is_list(args) do
    with :error <- unary_call(ast, fun),
         :error <- binary_call(ast, fun),
         :error <- sigil_call(ast, fun) do
      {list, last} = split_last(args)

      result =
        if kw_blocks?(last) do
          case list do
            [] -> call_to_string(target, fun) <> kw_blocks_to_string(last, fun)
            _ -> call_to_string_with_args(target, list, fun) <> kw_blocks_to_string(last, fun)
          end
        else
          call_to_string_with_args(target, args, fun)
        end

      fun.(ast, result)
    else
      {:ok, value} -> value
    end
  end

  def to_string({left, right}, fun) do
    to_string({:{}, [], [left, right]}, fun)
  end

  def to_string(list, fun) when is_list(list) do
    result =
      cond do
        list == [] ->
          "[]"

        :io_lib.printable_list(list) ->
          {escaped, _} = Identifier.escape(IO.chardata_to_string(list), ?')
          IO.iodata_to_binary([?', escaped, ?'])

        Inspect.List.keyword?(list) ->
          "[" <> kw_list_to_string(list, fun) <> "]"

        true ->
          "[" <> Enum.map_join(list, ", ", &to_string(&1, fun)) <> "]"
      end

    fun.(list, result)
  end

  def to_string(other, fun) do
    fun.(other, inspect_no_limit(other))
  end

  defp inspect_no_limit(value) do
    Kernel.inspect(value, limit: :infinity, printable_limit: :infinity)
  end

  defp bitpart_to_string({:"::", meta, [left, right]} = ast, fun) do
    result =
      if meta[:inferred_bitstring_spec] do
        to_string(left, fun)
      else
        op_to_string(left, fun, :"::", :left) <>
          "::" <> bitmods_to_string(right, fun, :"::", :right)
      end

    fun.(ast, result)
  end

  defp bitpart_to_string(ast, fun) do
    to_string(ast, fun)
  end

  defp bitmods_to_string({op, _, [left, right]} = ast, fun, _, _) when op in [:*, :-] do
    result =
      bitmods_to_string(left, fun, op, :left) <>
        Atom.to_string(op) <> bitmods_to_string(right, fun, op, :right)

    fun.(ast, result)
  end

  defp bitmods_to_string(other, fun, parent_op, side) do
    op_to_string(other, fun, parent_op, side)
  end

  kw_keywords = [:do, :rescue, :catch, :else, :after]

  defp kw_blocks?([{:do, _} | _] = kw) do
    Enum.all?(kw, &match?({x, _} when x in unquote(kw_keywords), &1))
  end

  defp kw_blocks?(_), do: false

  defp interpolated?({:<<>>, _, [_ | _] = parts}) do
    Enum.all?(parts, fn
      {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [_]}, {:binary, _, _}]} -> true
      binary when is_binary(binary) -> true
      _ -> false
    end)
  end

  defp interpolated?(_) do
    false
  end

  defp interpolate(ast, fun), do: interpolate(ast, "\"", "\"", fun)

  defp interpolate({:<<>>, _, [parts]}, left, right, _) when left in [~s["""\n], ~s['''\n]] do
    <<left::binary, parts::binary, right::binary>>
  end

  defp interpolate({:<<>>, _, parts}, left, right, fun) do
    parts =
      Enum.map_join(parts, "", fn
        {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [arg]}, {:binary, _, _}]} ->
          "\#{" <> to_string(arg, fun) <> "}"

        binary when is_binary(binary) ->
          binary = inspect_no_limit(binary)
          binary = binary_part(binary, 1, byte_size(binary) - 2)
          escape_sigil(binary, left)
      end)

    <<left::binary, parts::binary, right::binary>>
  end

  defp escape_sigil(parts, "("), do: String.replace(parts, ")", ~S"\)")
  defp escape_sigil(parts, "{"), do: String.replace(parts, "}", ~S"\}")
  defp escape_sigil(parts, "["), do: String.replace(parts, "]", ~S"\]")
  defp escape_sigil(parts, "<"), do: String.replace(parts, ">", ~S"\>")
  defp escape_sigil(parts, delimiter), do: String.replace(parts, delimiter, "\\#{delimiter}")

  defp module_to_string(atom, _fun) when is_atom(atom) do
    inspect_no_limit(atom)
  end

  defp module_to_string({:&, _, [val]} = expr, fun) when not is_integer(val) do
    to_string(expr, fun)
  end

  defp module_to_string({:fn, _, _} = expr, fun) do
    to_string(expr, fun)
  end

  defp module_to_string({_, _, [_ | _] = args} = expr, fun) do
    if kw_blocks?(List.last(args)) do
      to_string(expr, fun)
    else
      to_string(expr, fun)
    end
  end

  defp module_to_string(expr, fun) do
    to_string(expr, fun)
  end

  defp unary_call({op, _, [arg]} = ast, fun) when is_atom(op) do
    case Identifier.unary_op(op) do
      {_, _} ->
        if op == :not or op_expr?(arg) do
          {:ok, fun.(ast, Atom.to_string(op) <> " " <> to_string(arg, fun) <> " ")}
        else
          {:ok, fun.(ast, Atom.to_string(op) <> to_string(arg, fun))}
        end

      :error ->
        :error
    end
  end

  defp unary_call(_, _) do
    :error
  end

  defp binary_call({op, _, [left, right]} = ast, fun) when is_atom(op) do
    case Identifier.binary_op(op) do
      {_, _} ->
        left = op_to_string(left, fun, op, :left)
        right = op_to_string(right, fun, op, :right)
        op = if op in [:..], do: "#{op}", else: " #{op} "
        {:ok, fun.(ast, left <> op <> right)}

      :error ->
        :error
    end
  end

  defp binary_call(_, _) do
    :error
  end

  defp sigil_call({sigil, meta, [{:<<>>, _, _} = parts, args]} = ast, fun)
       when is_atom(sigil) and is_list(args) do
    delimiter = Keyword.get(meta, :delimiter, "\"")
    {left, right} = delimiter_pair(delimiter)

    case Atom.to_string(sigil) do
      <<"sigil_", name>> when name >= ?A and name <= ?Z ->
        args = sigil_args(args, fun)
        {:<<>>, _, [binary]} = parts
        formatted = <<?~, name, left::binary, binary::binary, right::binary, args::binary>>
        {:ok, fun.(ast, formatted)}

      <<"sigil_", name>> when name >= ?a and name <= ?z ->
        args = sigil_args(args, fun)
        formatted = "~" <> <<name>> <> interpolate(parts, left, right, fun) <> args
        {:ok, fun.(ast, formatted)}

      _ ->
        :error
    end
  end

  defp sigil_call(_other, _fun) do
    :error
  end

  defp delimiter_pair("["), do: {"[", "]"}
  defp delimiter_pair("{"), do: {"{", "}"}
  defp delimiter_pair("("), do: {"(", ")"}
  defp delimiter_pair("<"), do: {"<", ">"}
  defp delimiter_pair("\"\"\""), do: {"\"\"\"\n", "\"\"\""}
  defp delimiter_pair("'''"), do: {"'''\n", "'''"}
  defp delimiter_pair(str), do: {str, str}

  defp sigil_args([], _fun), do: ""
  defp sigil_args(args, fun), do: fun.(args, List.to_string(args))

  defp op_expr?(expr) do
    case expr do
      {op, _, [_, _]} ->
        Identifier.binary_op(op) != :error

      {op, _, [_]} ->
        Identifier.unary_op(op) != :error

      _ ->
        false
    end
  end

  defp call_to_string(atom, _fun) when is_atom(atom), do: Atom.to_string(atom)
  defp call_to_string({:., _, [arg]}, fun), do: module_to_string(arg, fun) <> "."

  defp call_to_string({:., _, [left, right]}, fun) when is_atom(right),
    do: module_to_string(left, fun) <> "." <> call_to_string_for_atom(right)

  defp call_to_string({:., _, [left, right]}, fun),
    do: module_to_string(left, fun) <> "." <> call_to_string(right, fun)

  defp call_to_string(other, fun), do: to_string(other, fun)

  defp call_to_string_with_args(target, args, fun) do
    # IO.inspect target, label: "Target "
    if target in Keyword.keys(@locals_without_parens) do
      target = call_to_string(target, fun)
      args = args_to_string(args, fun)
      target <> " " <> args
    else
      target = call_to_string(target, fun)
      args = args_to_string(args, fun)
      target <> "(" <> args <> ")"
    end
  end

  defp call_to_string_for_atom(atom) do
    Identifier.inspect_as_function(atom)
  end

  defp args_to_string(args, fun) do
    {list, last} = split_last(args)

    if last != [] and Inspect.List.keyword?(last) do
      prefix =
        case list do
          [] -> ""
          _ -> Enum.map_join(list, ", ", &to_string(&1, fun)) <> ", "
        end

      prefix <> kw_list_to_string(last, fun)
    else
      Enum.map_join(args, ", ", &to_string(&1, fun))
    end
  end

  defp kw_blocks_to_string(kw, fun) do
    Enum.reduce(unquote(kw_keywords), " ", fn x, acc ->
      case Keyword.has_key?(kw, x) do
        true -> acc <> kw_block_to_string(x, Keyword.get(kw, x), fun)
        false -> acc
      end
    end) <> "end"
  end

  defp kw_block_to_string(key, value, fun) do
    block = adjust_new_lines(block_to_string(value, fun), "\n  ")
    Atom.to_string(key) <> "\n  " <> block <> "\n"
  end

  defp block_to_string([{:->, _, _} | _] = block, fun) do
    Enum.map_join(block, "\n", fn {:->, _, [left, right]} ->
      left = comma_join_or_empty_paren(left, fun, false)
      left <> "->\n  " <> adjust_new_lines(block_to_string(right, fun), "\n  ")
    end)
  end

  defp block_to_string({:__block__, _, exprs}, fun) do
    Enum.map_join(exprs, "\n", &to_string(&1, fun))
  end

  defp block_to_string(other, fun), do: to_string(other, fun)

  defp map_to_string([{:|, _, [update_map, update_args]}], fun) do
    to_string(update_map, fun) <> " | " <> map_to_string(update_args, fun)
  end

  defp map_to_string(list, fun) do
    cond do
      Inspect.List.keyword?(list) -> kw_list_to_string(list, fun)
      true -> map_list_to_string(list, fun)
    end
  end

  defp kw_list_to_string(list, fun) do
    Enum.map_join(list, ", ", fn {key, value} ->
      Identifier.inspect_as_key(key) <> " " <> to_string(value, fun)
    end)
  end

  defp map_list_to_string(list, fun) do
    Enum.map_join(list, ", ", fn
      {key, value} -> to_string(key, fun) <> " => " <> to_string(value, fun)
      other -> to_string(other, fun)
    end)
  end

  defp wrap_in_parenthesis(expr, fun) do
    "(" <> to_string(expr, fun) <> ")"
  end

  defp op_to_string({op, _, [_, _]} = expr, fun, parent_op, side) when is_atom(op) do
    case Identifier.binary_op(op) do
      {_, prec} ->
        {parent_assoc, parent_prec} = Identifier.binary_op(parent_op)

        cond do
          parent_prec < prec -> to_string(expr, fun)
          parent_prec > prec -> wrap_in_parenthesis(expr, fun)
          parent_assoc == side -> to_string(expr, fun)
          true -> wrap_in_parenthesis(expr, fun)
        end

      :error ->
        to_string(expr, fun)
    end
  end

  defp op_to_string(expr, fun, _, _), do: to_string(expr, fun)

  defp arrow_to_string(pairs, fun, paren \\ false) do
    Enum.map_join(pairs, "; ", fn {:->, _, [left, right]} ->
      left = comma_join_or_empty_paren(left, fun, paren)
      left <> "-> " <> to_string(right, fun)
    end)
  end

  defp comma_join_or_empty_paren([], _fun, true), do: "() "
  defp comma_join_or_empty_paren([], _fun, false), do: ""

  defp comma_join_or_empty_paren(left, fun, _) do
    Enum.map_join(left, ", ", &to_string(&1, fun)) <> " "
  end

  defp split_last([]) do
    {[], []}
  end

  defp split_last(args) do
    {left, [right]} = Enum.split(args, -1)
    {left, right}
  end

  defp adjust_new_lines(block, replacement) do
    for <<x <- block>>, into: "" do
      case x == ?\n do
        true -> replacement
        false -> <<x>>
      end
    end
  end

  def expand_once(ast, env) do
    elem(do_expand_once(ast, env), 0)
  end

  defp do_expand_once({:__aliases__, meta, _} = original, env) do
    case :elixir_aliases.expand(original, env) do
      receiver when is_atom(receiver) ->
        :elixir_env.trace({:alias_reference, meta, receiver}, env)
        {receiver, true}

      aliases ->
        aliases = :lists.map(&elem(do_expand_once(&1, env), 0), aliases)

        case :lists.all(&is_atom/1, aliases) do
          true ->
            receiver = :elixir_aliases.concat(aliases)
            :elixir_env.trace({:alias_reference, meta, receiver}, env)
            {receiver, true}

          false ->
            {original, false}
        end
    end
  end

  defp do_expand_once({:__MODULE__, _, atom}, env) when is_atom(atom), do: {env.module, true}

  defp do_expand_once({:__DIR__, _, atom}, env) when is_atom(atom),
    do: {:filename.dirname(env.file), true}

  defp do_expand_once({:__ENV__, _, atom}, env) when is_atom(atom),
    do: {{:%{}, [], Map.to_list(env)}, true}

  defp do_expand_once({{:., _, [{:__ENV__, _, atom}, field]}, _, []} = original, env)
       when is_atom(atom) and is_atom(field) do
    if Map.has_key?(env, field) do
      {Map.get(env, field), true}
    else
      {original, false}
    end
  end

  defp do_expand_once({atom, meta, context} = original, _env)
       when is_atom(atom) and is_list(meta) and is_atom(context) do
    {original, false}
  end

  defp do_expand_once({atom, meta, args} = original, env)
       when is_atom(atom) and is_list(args) and is_list(meta) do
    arity = length(args)

    if special_form?(atom, arity) do
      {original, false}
    else
      module = env.module

      extra =
        if function_exported?(module, :__info__, 1) do
          [{module, module.__info__(:macros)}]
        else
          []
        end

      expand = :elixir_dispatch.expand_import(meta, {atom, length(args)}, args, env, extra, true)

      case expand do
        {:ok, receiver, quoted} ->
          next = :elixir_module.next_counter(module)
          {:elixir_quote.linify_with_context_counter(0, {receiver, next}, quoted), true}

        {:ok, Kernel, op, [arg]} when op in [:+, :-] ->
          case expand_once(arg, env) do
            integer when is_integer(integer) -> {apply(Kernel, op, [integer]), true}
            _ -> {original, false}
          end

        {:ok, _receiver, _name, _args} ->
          {original, false}

        :error ->
          {original, false}
      end
    end
  end

  defp do_expand_once({{:., _, [left, right]}, meta, args} = original, env) when is_atom(right) do
    {receiver, _} = do_expand_once(left, env)

    case is_atom(receiver) do
      false ->
        {original, false}

      true ->
        expand = :elixir_dispatch.expand_require(meta, receiver, {right, length(args)}, args, env)

        case expand do
          {:ok, receiver, quoted} ->
            next = :elixir_module.next_counter(env.module)
            {:elixir_quote.linify_with_context_counter(0, {receiver, next}, quoted), true}

          :error ->
            {original, false}
        end
    end
  end

  defp do_expand_once(other, _env), do: {other, false}

  def special_form?(name, arity) when is_atom(name) and is_integer(arity) do
    :elixir_import.special_form(name, arity)
  end

  def operator?(name, 2) when is_atom(name), do: Identifier.binary_op(name) != :error
  def operator?(name, 1) when is_atom(name), do: Identifier.unary_op(name) != :error
  def operator?(name, arity) when is_atom(name) and is_integer(arity), do: false

  def quoted_literal?(term)

  def quoted_literal?({:__aliases__, _, args}),
    do: quoted_literal?(args)

  def quoted_literal?({:%, _, [left, right]}),
    do: quoted_literal?(left) and quoted_literal?(right)

  def quoted_literal?({:%{}, _, args}), do: quoted_literal?(args)
  def quoted_literal?({:{}, _, args}), do: quoted_literal?(args)
  def quoted_literal?({left, right}), do: quoted_literal?(left) and quoted_literal?(right)
  def quoted_literal?(list) when is_list(list), do: Enum.all?(list, &quoted_literal?/1)

  def quoted_literal?(term),
    do: is_atom(term) or is_number(term) or is_binary(term) or is_function(term)

  def expand(ast, env) do
    expand_until({ast, true}, env)
  end

  defp expand_until({ast, true}, env) do
    expand_until(do_expand_once(ast, env), env)
  end

  defp expand_until({ast, false}, _env) do
    ast
  end

  def underscore(atom) when is_atom(atom) do
    "Elixir." <> rest = Atom.to_string(atom)
    underscore(rest)
  end

  def underscore(<<h, t::binary>>) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  def underscore("") do
    ""
  end

  defp do_underscore(<<h, t, rest::binary>>, _)
       when h >= ?A and h <= ?Z and not (t >= ?A and t <= ?Z) and t != ?. and t != ?_ do
    <<?_, to_lower_char(h), t>> <> do_underscore(rest, t)
  end

  defp do_underscore(<<h, t::binary>>, prev)
       when h >= ?A and h <= ?Z and not (prev >= ?A and prev <= ?Z) and prev != ?_ do
    <<?_, to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<?., t::binary>>, _) do
    <<?/>> <> underscore(t)
  end

  defp do_underscore(<<h, t::binary>>, _) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<>>, _) do
    <<>>
  end

  def camelize(string)

  def camelize(""), do: ""
  def camelize(<<?_, t::binary>>), do: camelize(t)
  def camelize(<<h, t::binary>>), do: <<to_upper_char(h)>> <> do_camelize(t)

  defp do_camelize(<<?_, ?_, t::binary>>), do: do_camelize(<<?_, t::binary>>)

  defp do_camelize(<<?_, h, t::binary>>) when h >= ?a and h <= ?z,
    do: <<to_upper_char(h)>> <> do_camelize(t)

  defp do_camelize(<<?_, h, t::binary>>) when h >= ?0 and h <= ?9, do: <<h>> <> do_camelize(t)
  defp do_camelize(<<?_>>), do: <<>>
  defp do_camelize(<<?/, t::binary>>), do: <<?.>> <> camelize(t)
  defp do_camelize(<<h, t::binary>>), do: <<h>> <> do_camelize(t)
  defp do_camelize(<<>>), do: <<>>

  defp to_upper_char(char) when char >= ?a and char <= ?z, do: char - 32
  defp to_upper_char(char), do: char

  defp to_lower_char(char) when char >= ?A and char <= ?Z, do: char + 32
  defp to_lower_char(char), do: char
end
