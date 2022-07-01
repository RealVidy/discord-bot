defmodule DistributedNostrum.ProcessGroupSingleton do
  use GenServer

  require Logger

  @doc """
  Start the manager process, registering it under a unique name.
  """
  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: :singleton_nostrum_starter)
  end

  @doc false
  def init(state) do
    start(state)
  end

  @doc false
  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    {:noreply, start(state)}
  end

  defp start(state) do
    with {:error, {:already_started, pid}} <-
           GenServer.start_link(DistributedNostrum.Starter, state,
             name: via_tuple(DistributedNostrum.Starter)
           ) do
      Process.monitor(pid)
      {:ok, pid}
    end
  end

  defp via_tuple(name) do
    DiscordBot.Via.region_name(name)
  end
end
