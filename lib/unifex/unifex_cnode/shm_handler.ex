defmodule Unifex.UnifexCNode.ShmHandler do
  use GenServer
  require Shmex

  def start() do
    state = MapSet.new()
    GenServer.start(__MODULE__, state)
  end

  @impl true
  def init(state \\ MapSet.new()) do
    {:ok, state}
  end

  @impl true
  def handle_call({:alloc, size}, _from, state) do
    shm = Shmex.empty(size)
    state = state |> MapSet.put(shm)
    {:reply, shm, state}
  end

  @impl true
  def handle_call({:realloc, %Shmex{} = shm, dest_size}, _from, state) do
    state = state |> MapSet.delete(shm)
    shm = Shmex.realloc(shm, dest_size)
    state = state |> MapSet.put(shm)
    {:reply, shm, state}
  end

  @impl true
  def handle_cast({:release, %Shmex{} = shm}, state) do
    state = state |> MapSet.delete(shm)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:release, shm_list}, state) when is_list(shm_list) do
    shm_set = MapSet.new(shm_list)
    state = state |> MapSet.difference(shm_set)
    {:noreply, state}
  end
end
