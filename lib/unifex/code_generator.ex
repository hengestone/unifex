defmodule Unifex.CodeGenerator do
  alias Unifex.CodeGenerator.{CNodeCodeGenerator, NIFCodeGenerator}

  @type code_t :: String.t()

  @callback generate_header(
              name :: any,
              module :: any,
              functions :: any,
              results :: any,
              sends :: any,
              callbacks :: any,
              use_state :: boolean()
            ) :: code_t()
  @callback generate_source(
              name :: any,
              module :: any,
              functions :: any,
              results :: any,
              dirty_funs :: any,
              sends :: any,
              callbacks :: any,
              use_state :: boolean()
            ) :: code_t()

  @spec generate_code(
          name :: String.t(),
          specs :: Unifex.SpecsParser.parsed_specs_t()
        ) ::
          {code_t(), code_t()}
  def generate_code(name, specs) do
    implementation = specs |> choose_implementation()

    module = specs |> Keyword.get(:module)
    fun_specs = specs |> Keyword.get_values(:fun_specs)
    dirty_funs = specs |> Keyword.get_values(:dirty) |> List.flatten() |> Map.new()
    sends = specs |> Keyword.get_values(:sends)
    callbacks = specs |> Keyword.get_values(:callbacks)
    use_state = specs |> Keyword.get(:use_state, false)

    {functions, results} =
      fun_specs
      |> Enum.map(fn {name, args, results} -> {{name, args}, {name, results}} end)
      |> Enum.unzip()

    results = results |> Enum.flat_map(fn {name, specs} -> specs |> Enum.map(&{name, &1}) end)

    header =
      implementation.generate_header(
        name,
        module,
        functions,
        results,
        sends,
        callbacks,
        use_state
      )

    source =
      implementation.generate_source(
        name,
        module,
        functions,
        results,
        dirty_funs,
        sends,
        callbacks,
        use_state
      )

    {header, source}
  end

  defp choose_implementation(specs) do
    if specs |> Keyword.get(:cnode_mode, false) do
      CNodeCodeGenerator
    else
      NIFCodeGenerator
    end
  end
end
