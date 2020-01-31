defmodule Unifex.CnodeNativeCodeGenerator do
  alias Unifex.{NativeCodeGenerator, BaseType}
  alias Unifex.NativeCodeGenerator.CodeGeneratorUtils
  use CodeGeneratorUtils

  @type code_t() :: String.t()

  defdelegate generate_functions(results, generator), to: CodeGeneratorUtils
  defdelegate generate_functions_declarations(results, generator), to: CodeGeneratorUtils

  def generate_sources() do
    ""
  end

  def generate_header() do
    ""
  end

  def generate_includes() do
    ""
  end

  defp generate_args_decoding(args) do
    args
    |> Enum.map(fn
      {name, :atom} ->
        ~g<char #{name}[2048];
                ei_decode_atom(&in_buff, &index, #{name}));>

      {name, :int} ->
        ~g<long long #{name};
                ei_decode_longlong(&in_buff, &index, #{name});>

      {name, :string} ->
        ~g<char #{name}[2048];
                long #{name}_len;
                ei_decode_binary((void*) &in_buff, &index, #{name}, &#{name}_len);
                #{name}[#{name}_len] = 0;>
    end)
    |> Enum.join("\n")
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

  # defp generate_results_encoding({a, b}) do
  #     tuple_encoding = "ei_x_encode_tuple_header(&out_buff, 2);"
  #     content_encoding = [a, b] |> Enum.map(generate_result_encoding)
  #     [tuple_encoding | content_encoding] |> Enum.join("\n")
  # end

  def generate_result_function({name, specs}) do
    declaration = generate_result_function_declaration({name, specs})

    {result, meta} =
      CodeGenerator.generate_function_spec_traverse_helper(CNodeCodeGenerator, specs)

    args_len = meta |> Keyword.get_values(:arg) |> length()

    IO.inspect(result)

    ~g<#{declaration} {
            ei_x_encode_tuple_header(out_buff, #{args_len});
            #{result |> Enum.join("\n")}
        }>
  end

  def generate_result_function_declaration({name, specs}) do
    {_result, meta} =
      CodeGenerator.generate_function_spec_traverse_helper(CNodeCodeGenerator, specs)

    args = meta |> Keyword.get_values(:arg)
    labels = meta |> Keyword.get_values(:label)

    args_declarations =
      [~g<ei_x_buff* out_buff> | args |> Enum.flat_map(&BaseType.generate_declaration/1)]
      |> Enum.join(", ")

    ~g<void #{[name, :result | labels] |> Enum.join("_")}(#{args_declarations})>
  end

  def generate_handle_message(fun_names) do
    if_statements =
      fun_names
      |> Enum.map(fn
        f_name ->
          ~g"""
          if (strcmp(fun_name, \"#{f_name}\") == 0) {
              #{f_name}_caller(in_buff->buff, &index, node_name, ei_fd, &emsg.from);
          }
          """r
      end)

    last_statement = """
    {
        fprintf(stderr, \"no match for function %s\", fun_name);
        fflush(stderr);
    }
    """

    handling = Enum.concat(if_statements, [last_statement]) |> Enum.join(" else ")

    ~g"""
    int handle_message(int ei_fd, const char *node_name, erlang_msg emsg,
            ei_x_buff *in_buf) {

        int index = 0;
        int version;
        ei_decode_version(in_buf->buff, &index, &version);

        int arity;
        ei_decode_tuple_header(buff, &index, arity);

        char fun_name[2048];
        decode_message_type(in_buf->buff, &index, fun_name);
        
        #{handling}
    }
    """r
  end

  def generate_cnode_generic_utilities() do
    ~g"""
    int receive(int ei_fd, const char *node_name) {
        ei_x_buff in_buf;
        ei_x_new(&in_buf);
        erlang_msg emsg;
        int res = 0;
        switch (ei_xreceive_msg_tmo(ei_fd, &emsg, &in_buf, 100)) {
        case ERL_TICK:
          break;
        case ERL_ERROR:
          res = erl_errno != ETIMEDOUT;
          break;
        default:
          if (emsg.msgtype == ERL_REG_SEND &&
              handle_message(ei_fd, node_name, emsg, &in_buf)) {
            res = -1;
          }
          break;
        }
      
        ei_x_free(&in_buf);
        return res;
      }

    int validate_args(int argc, char **argv) {
        if (argc != 6) {
          return 1;
        }
        for (int i = 1; i < argc; i++) {
          if (strlen(argv[i]) > 255) {
            return 1;
          }
        }
        return 0;
      }
      

    int main(int argc, char **argv) {
      if (validate_args(argc, argv)) {
        fprintf(stderr,
                "%s <host_name> <alive_name> <node_name> <cookie> <creation>\r\n",
                argv[0]);
        return 1;
      }

      char host_name[256];
      strcpy(host_name, argv[1]);
      char alive_name[256];
      strcpy(alive_name, argv[2]);
      char node_name[256];
      strcpy(node_name, argv[3]);
      char cookie[256];
      strcpy(cookie, argv[4]);
      short creation = (short)atoi(argv[5]);

      int listen_fd;
      int port;
      if (listen_sock(&listen_fd, &port)) {
        DEBUG("listen error");
        return 1;
      }
      DEBUG("listening at %d", port);

      ei_cnode ec;
      struct in_addr addr;
      addr.s_addr = inet_addr("127.0.0.1");
      if (ei_connect_xinit(&ec, host_name, alive_name, node_name, &addr, cookie,
                           creation) < 0) {
        DEBUG("init error: %d", erl_errno);
        return 1;
      }
      DEBUG("initialized %s (%s)", ei_thisnodename(&ec), inet_ntoa(addr));

      if (ei_publish(&ec, port) == -1) {
        DEBUG("publish error: %d", erl_errno);
        return 1;
      }
      DEBUG("published");
      printf("ready\r\n");
      fflush(stdout);

      ErlConnect conn;
      int ei_fd = ei_accept_tmo(&ec, listen_fd, &conn, 5000);
      if (ei_fd == ERL_ERROR) {
        DEBUG("accept error: %d", erl_errno);
        return 1;
      }
      DEBUG("accepted %s", conn.nodename);

      int res = 0;
      int cont = 1;
      while (cont) {
        switch (receive(ei_fd, node_name)) {
        case 0:
          break;
        case 1:
          DEBUG("disconnected");
          cont = 0;
          break;
        default:
          DEBUG("error handling message, disconnecting");
          cont = 0;
          res = 1;
          break;
        }
      }
      close(listen_fd);
      close(ei_fd);
      return res;
    }
    """r
  end

  defp generate_implemented_function_declaration({name, args}) do
    args_declarations =
      args
      |> Enum.flat_map(&BaseType.generate_declaration/1)
      |> Enum.join(", ")

    ~g<void #{name}(#{args_declarations})>
  end

  def generate_caller_function({name, args}) do
    declaration = generate_caller_function_declaration(name)
    args_decoding = generate_args_decoding(args)

    implemented_fun_args =
      ["&out_buff" | args |> Enum.map(fn {name, type} -> to_string(name) end)]
      |> Enum.join(", ")

    implemented_fun_call = ~g<#{name}(#{implemented_fun_args});>

    ~g<#{declaration} {
            ei_x_buff out_buff;
            prepare_ei_x_buff(&out_buff, node_name);

            #{args_decoding}
            #{implemented_fun_call}

            ei_send(ei_fd, e_pid, out_buff.buff, out_buff.index);
            ei_x_free(&out_buff);
            return 0;
        }>
  end

  def generate_caller_function_declaration({name, args}) do
    generate_caller_function_declaration(name)
  end

  def generate_caller_function_declaration(name) do
    ~g"void #{name}_caller(ei_buff * in_buff, int *index, const char *node_name, int ei_fd, erlang_pid * e_pid)"
  end

  def generate_header(name, module, functions, results, sends, callbacks) do
    ~g"""
    #pragma once

    #include <stdio.h>
    #include <stdint.h>
    #include <erl_nif.h>
    #include <unifex/unifex.h>
    #include <unifex/payload.h>
    #include "#{InterfaceIO.user_header_path(name)}"

    #ifdef __cplusplus
    extern "C" {
    #endif

    #{generate_functions_declarations(functions, &generate_implemented_function_declaration/1)}

    #{generate_functions_declarations(results, &generate_result_function_declaration/1)}

    #{generate_functions_declarations(functions, &generate_caller_function_declaration/1)}

    #ifdef __cplusplus
    }
    #endif
    """r
  end

  defp generate_source(name, module, functions, results, dirty_funs, sends, callbacks) do
    {fun_names, args} = Enum.unzip(functions)

    ~g"""
    #include "#{name}.h"

    #{generate_functions(results, &generate_result_function/1)}
    #{generate_functions(functions, &generate_caller_function/1)}

    #{generate_handle_message(fun_names)}

    #{generate_cnode_generic_utilities()}
    """r
  end
end
