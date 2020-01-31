defmodule Unifex.NativeCodeGenerator.CodeGenerator do
  use Bunch

  @callback generate_result(res :: any) :: any
  @callback generate_tuple_maker(content :: any) :: any

  @callback generate_header(
              name :: any,
              module :: any,
              functions :: any,
              results :: any,
              sends :: any,
              callbacks :: any
            ) :: any
  @callback generate_source(
              name :: any,
              module :: any,
              functions :: any,
              results :: any,
              dirty_funs :: any,
              sends :: any,
              callbacks :: any
            ) :: any

  @spec generate_code(
          implementation :: any,
          name :: String.t(),
          specs :: Unifex.SpecsParser.parsed_specs_t()
        ) :: {String.t(), String.t()}
  def generate_code(implementation, name, specs) do
    module = specs |> Keyword.get(:module)
    fun_specs = specs |> Keyword.get_values(:fun_specs)
    dirty_funs = specs |> Keyword.get_values(:dirty) |> List.flatten() |> Map.new()
    sends = specs |> Keyword.get_values(:sends)
    callbacks = specs |> Keyword.get_values(:callbacks)

    {functions, results} =
      fun_specs
      |> Enum.map(fn {name, args, results} -> {{name, args}, {name, results}} end)
      |> Enum.unzip()

    results = results |> Enum.flat_map(fn {name, specs} -> specs |> Enum.map(&{name, &1}) end)
    header = implementation.generate_header(name, module, functions, results, sends, callbacks)

    source =
      implementation.generate_source(
        name,
        module,
        functions,
        results,
        dirty_funs,
        sends,
        callbacks
      )

    {header, source}
  end

  def generate_function_spec_traverse_helper(implementation, node) do
    node
    |> case do
      {:__aliases__, [alias: als], atoms} ->
        generate_function_spec_traverse_helper(implementation, als || Module.concat(atoms))

      atom when is_atom(atom) ->
        {implementation.generate_result({:"\"#{atom}\"", :atom}), []}

      {:"::", _, [name, {:label, _, _}]} when is_atom(name) ->
        {implementation.generate_result({:"\"#{name}\"", :atom}), label: name}

      {:"::", _, [{name, _, _}, {type, _, _}]} ->
        {implementation.generate_result({name, type}), arg: {name, type}}

      {:"::", meta, [name_var, [{type, type_meta, type_ctx}]]} ->
        generate_function_spec_traverse_helper(
          implementation,
          {:"::", meta, [name_var, {{:list, type}, type_meta, type_ctx}]}
        )

      {a, b} ->
        generate_function_spec_traverse_helper(implementation, {:{}, [], [a, b]})

      {:{}, _, content} ->
        {results, meta} =
          content
          |> Enum.map(fn n -> generate_function_spec_traverse_helper(implementation, n) end)
          |> Enum.unzip()

        {implementation.generate_tuple_maker(results), meta}

      [{_name, _, _} = name_var] ->
        generate_function_spec_traverse_helper(
          implementation,
          {:"::", [], [name_var, [name_var]]}
        )

      {_name, _, _} = name_var ->
        generate_function_spec_traverse_helper(implementation, {:"::", [], [name_var, name_var]})
    end
    ~> ({result, meta} -> {result, meta |> List.flatten()})
  end
end
