defmodule DistributedNostrum.Cache.ChannelCache do
  @moduledoc """
  See module doc for `DistributedNostrum.Bot` as this serves the same purpose for Nostrum's ChannelCache process
  """
  use GenServer

  alias Nostrum.Cache.ChannelCache
  alias Nostrum.Struct.Channel

  # Init

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, [init_args], name: via_tuple(__MODULE__))
  end

  # Client

  @spec get(Channel.id()) :: {:error, atom} | {:ok, Channel.t()}
  def get(id) do
    GenServer.call(via_tuple(__MODULE__), {:get, id})
  end

  # Server

  @impl GenServer
  def init(_args) do
    {:ok, :initial_state}
  end

  @impl GenServer
  def handle_call({:get, id}, _from, state) do
    {:reply, ChannelCache.get(id), state}
  end

  defp via_tuple(name) do
    DiscordBot.Via.region_name(name)
  end
end
