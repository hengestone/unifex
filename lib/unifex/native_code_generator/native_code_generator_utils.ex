defmodule Unifex.NativeCodeGenerator.CodeGeneratorUtils do
  alias Unifex.NativeCodeGenerator.CodeGenerator

  defmacro __using__(_args) do
    quote do
      import unquote(__MODULE__), only: [gen: 2, sigil_g: 2]
    end
  end

  @doc """
  Sigil used for indentation of generated code.

  By itself it does nothing, but has very useful flags:
  * `r` trims trailing whitespaces of each line and removes subsequent empty
    lines
  * `t` trims the string
  * `i` indents all but the first line. Helpful when used
    inside string interpolation that already has been indented
  * `I` indents every line of string
  """
  @spec sigil_g(String.t(), charlist()) :: String.t()
  def sigil_g(content, 'r' ++ flags) do
    content =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing/1)
      |> Enum.reduce([], fn
        "", ["" | _] = acc -> acc
        v, acc -> [v | acc]
      end)
      |> Enum.reverse()
      |> Enum.join("\n")

    sigil_g(content, flags)
  end

  def sigil_g(content, 't' ++ flags) do
    content = content |> String.trim()
    sigil_g(content, flags)
  end

  def sigil_g(content, 'i' ++ flags) do
    [first | rest] = content |> String.split("\n")
    content = [first | rest |> Enum.map(&indent/1)] |> Enum.join("\n")
    sigil_g(content, flags)
  end

  def sigil_g(content, 'I' ++ flags) do
    lines = content |> String.split("\n")
    content = lines |> Enum.map(&indent/1) |> Enum.join("\n")
    sigil_g(content, flags)
  end

  def sigil_g(content, []) do
    content
  end

  @doc """
  Helper for generating code. Uses `sigil_g/2` underneath.

  It supports all the flags supported by `sigil_g/2` and the following ones:
  * `j(joiner)` - joins list of strings using `joiner`
  * n - alias for `j(\\n)`

  If passed a list and flags supported by `sigil_g/2`, each flag will be executed
  on each element of the list, until the list is joined by using `j` or `n` flag.
  """
  @spec gen(String.Chars.t() | [String.Chars.t()], charlist()) :: String.t() | [String.t()]
  def gen(content, 'j(' ++ flags) when is_list(content) do
    {joiner, ')' ++ flags} = flags |> Enum.split_while(&([&1] != ')'))
    content = content |> Enum.join("#{joiner}")
    gen(content, flags)
  end

  def gen(content, 'n' ++ flags) when is_list(content) do
    gen(content, 'j(\n)' ++ flags)
  end

  def gen(content, flags) when is_list(content) do
    content |> Enum.map(&gen(&1, flags))
  end

  def gen(content, flags) do
    sigil_g(content, flags)
  end

  def generate_functions(results, generator) do
    results
    |> Enum.map(generator)
    |> Enum.join("\n")
  end

  def generate_functions_declarations(results, generator) do
    results
    |> Enum.map(generator)
    |> Enum.map(&(&1 <> ";"))
    |> Enum.join("\n")
  end

  defp indent(line) do
    "  #{line}"
  end
end
