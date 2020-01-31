defmodule Unifex.NativeCodeGenerator.CNodeCodeGenerator do
  alias Unifex.NativeCodeGenerator.CodeGenerator
  @behaviour CodeGenerator

  use Unifex.NativeCodeGenerator.CodeGeneratorUtils

  @impl CodeGenerator
  def generate_result(res) do
    generate_result_encoding(res)
  end

  defp generate_result_encoding({var, :label}) do
    generate_result_encoding({var, :atom})
  end

  defp generate_result_encoding({var_name, :int}) do
    ~g<long long casted_#{var_name} = (long long) var_name;
        ei_x_encode_longlong(out_buff, casted_#{var_name});>
  end

  defp generate_result_encoding({var_name, :string}) do
    ~g<long #{var_name}_len = (long) strlen(#{var_name});
        ei_x_encode_binary(out_buff, #{var_name}, #{var_name}_len);>
  end

  defp generate_result_encoding({var_name, :atom}) do
    ~g<ei_x_encode_atom(out_buff, #{var_name});>
  end

  @impl CodeGenerator
  def generate_tuple_maker(content) do
    IO.inspect(content)
    # IO.inspect ~g<({
    #   const ERL_NIF_TERM terms[] = {
    #     #{content |> gen('j(,\n    )iit')}
    #   };
    #   enif_make_tuple_from_array(env, terms, #{length(content)});
    # })>
  end
end
