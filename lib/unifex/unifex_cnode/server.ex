defmodule Unifex.UnifexCNode.Server do
  @moduledoc false

  use GenServer
  require Logger
  alias Bundlex.CNode.NameStore

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    if opts.link?, do: Process.monitor(opts.caller)
    :ok = ensure_node_distributed()
    {name, creation} = NameStore.get_name()
    cnode = :"#{name}@#{host_name()}"

    port =
      Port.open(
        {:spawn_executable, Bundlex.build_path(opts.app, opts.native_name)},
        args: [host_name(), name, cnode, Node.get_cookie(), "#{creation}"],
        line: 2048
      )

    Process.send_after(self(), :timeout, 5000)

    {:ok,
     %{
       port: port,
       state: :waiting,
       caller: opts.caller,
       link?: opts.link?,
       cnode: cnode,
       msg_part?: false
     }}
  end

  @impl true
  def handle_info(
        {port, {:data, {:eol, 'dupa'}}},
        %{port: port, state: _any, msg_part?: false} = state
      ) do
    IO.puts("\n\n dozdalem 'dupa' X~~~~~~~~DDDDDDDDD \n\n\n\n")
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {port, {:data, {:eol, 'ready'}}},
        %{port: port, state: :waiting, msg_part?: false} = state
      ) do
    case Node.connect(state.cnode) do
      true ->
        send(
          state.caller,
          {self(), {:ok, %Unifex.UnifexCNode{server: self(), node: state.cnode}}}
        )

        {:noreply, %{state | state: :connected}}

      _ ->
        send(state.caller, {self(), {:error, :connect_to_cnode}})
        {:stop, :normal, state}
    end
  end

  def handle_info({port, {:data, {flag, data}}}, %{port: port} = state) do
    Logger.info("cnode#{inspect(self())}: #{data}")
    {:noreply, %{state | msg_part?: flag == :noeol}}
  end

  def handle_info(:timeout, state) do
    case state.state do
      :waiting ->
        send(state.caller, {self(), {:error, :spawn_cnode}})
        {:stop, :normal, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{caller: pid} = state) do
    disconnect(state.cnode)
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    if state.link?, do: Process.exit(state.caller, :shutdown)
    {:stop, reason, state}
  end

  def handle_info({:EXIT, _from, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({:EXIT, _from, reason}, state) do
    if state.link?, do: Process.exit(state.caller, reason)
    {:stop, reason, state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    {:stop, :normal, disconnect(state.cnode), state}
  end

  defp ensure_node_distributed(empd_status \\ :unknown) do
    if Node.alive?() do
      :ok
    else
      case Node.start(NameStore.get_self_name(), :shortnames) do
        {:ok, _pid} ->
          Node.set_cookie(:bundlex_cookie)
          :ok

        {:error, {:already_started, _pid}} ->
          # In case the node has been started after the `Node.alive?` check
          :ok

        {:error, _reason} when empd_status == :unknown ->
          Logger.info("Trying to start epmd...")
          System.cmd("epmd", ~w(-daemon))
          # ensure epmd finished starting
          System.cmd("epmd", ~w(-names))
          ensure_node_distributed(:start_tried)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp disconnect(cnode) do
    case Node.disconnect(cnode) do
      true ->
        NameStore.return_name(cnode |> node_name)
        :ok

      _ ->
        {:error, :disconnect_cnode}
    end
  end

  defp node_name(node) do
    node |> to_string() |> String.split("@") |> List.first()
  end

  defp host_name(node \\ Node.self()) do
    node |> to_string() |> String.split("@") |> List.last()
  end
end

# defmodule Unifex.UnifexCNode.Server do
#     @moduledoc false

#     use GenServer
#     require Logger
#     alias Bundlex.CNode.NameStore

#     @impl true
#     def init(opts) do
#       Process.flag(:trap_exit, true)
#       if opts.link?, do: Process.monitor(opts.caller)
#       :ok = ensure_node_distributed()
#       {name, creation} = NameStore.get_name()
#       cnode = :"#{name}@#{host_name()}"

#       port =
#         Port.open(
#           {:spawn_executable, Bundlex.build_path(opts.app, opts.native_name)},
#           args: [host_name(), name, cnode, Node.get_cookie(), "#{creation}"],
#           line: 2048
#         )

#       Process.send_after(self(), :timeout, 5000)

#       {:ok,
#        %{
#          port: port,
#          state: :waiting,
#          caller: opts.caller,
#          link?: opts.link?,
#          cnode: cnode,
#          msg_part?: false
#        }}
#     end

#     @impl true
#     def handle_info(
#           {port, {:data, {:eol, 'dupa'}}},
#           %{port: port, state: :waiting, msg_part?: false} = state
#         ) do
#       IO.puts "\n\n dozdalem 'dupa' X~~~~~~~~DDDDDDDDD \n\n\n\n"
#     end

#     @impl true
#     def handle_info(
#           {port, {:data, {:eol, 'ready'}}},
#           %{port: port, state: :waiting, msg_part?: false} = state
#         ) do
#       case Node.connect(state.cnode) do
#         true ->
#           send(state.caller, {self(), {:ok, %Bundlex.CNode{server: self(), node: state.cnode}}})
#           {:noreply, %{state | state: :connected}}

#         _ ->
#           send(state.caller, {self(), {:error, :connect_to_cnode}})
#           {:stop, :normal, state}
#       end
#     end

#     def handle_info({port, {:data, {flag, data}}}, %{port: port} = state) do
#       Logger.info("cnode#{inspect(self())}: #{data}")
#       {:noreply, %{state | msg_part?: flag == :noeol}}
#     end

#     def handle_info(:timeout, state) do
#       case state.state do
#         :waiting ->
#           send(state.caller, {self(), {:error, :spawn_cnode}})
#           {:stop, :normal, state}

#         _ ->
#           {:noreply, state}
#       end
#     end

#     def handle_info({:DOWN, _ref, :process, pid, _reason}, %{caller: pid} = state) do
#       disconnect(state.cnode)
#       {:stop, :normal, state}
#     end

#     def handle_info({:EXIT, port, reason}, %{port: port} = state) do
#       if state.link?, do: Process.exit(state.caller, :shutdown)
#       {:stop, reason, state}
#     end

#     def handle_info({:EXIT, _from, :normal}, state) do
#       {:noreply, state}
#     end

#     def handle_info({:EXIT, _from, reason}, state) do
#       if state.link?, do: Process.exit(state.caller, reason)
#       {:stop, reason, state}
#     end

#     @impl true
#     def handle_call(:stop, _from, state) do
#       {:stop, :normal, disconnect(state.cnode), state}
#     end

#     defp ensure_node_distributed(empd_status \\ :unknown) do
#       if Node.alive?() do
#         :ok
#       else
#         case Node.start(NameStore.get_self_name(), :shortnames) do
#           {:ok, _pid} ->
#             Node.set_cookie(:bundlex_cookie)
#             :ok

#           {:error, {:already_started, _pid}} ->
#             # In case the node has been started after the `Node.alive?` check
#             :ok

#           {:error, _reason} when empd_status == :unknown ->
#             Logger.info("Trying to start epmd...")
#             System.cmd("epmd", ~w(-daemon))
#             # ensure epmd finished starting
#             System.cmd("epmd", ~w(-names))
#             ensure_node_distributed(:start_tried)

#           {:error, reason} ->
#             {:error, reason}
#         end
#       end
#     end

#     defp disconnect(cnode) do
#       case Node.disconnect(cnode) do
#         true ->
#           NameStore.return_name(cnode |> node_name)
#           :ok

#         _ ->
#           {:error, :disconnect_cnode}
#       end
#     end

#     defp node_name(node) do
#       node |> to_string() |> String.split("@") |> List.first()
#     end

#     defp host_name(node \\ Node.self()) do
#       node |> to_string() |> String.split("@") |> List.last()
#     end
#   end