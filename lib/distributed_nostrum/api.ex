defmodule DistributedNostrum.Api do
  @moduledoc """
  See module doc for `DistributedNostrum.Bot` as this serves the same purpose for Nostrum's ChannelCache process
  """
  use GenServer

  alias Nostrum.Struct.Channel
  alias Nostrum.Error.ApiError

  # Init

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, [init_args], name: via_tuple(__MODULE__))
  end

  # Client

  @spec get_channel(Channel.id()) :: {:error, ApiError.t()} | {:ok, Channel.t()}
  def get_channel(channel_id) do
    GenServer.call(via_tuple(__MODULE__), {:get_channel, channel_id})
  end

  # Server

  @impl GenServer
  def init(_args) do
    {:ok, :initial_state}
  end

  @impl GenServer
  def handle_call({:get_channel, channel_id}, _from, state) do
    {:reply, Nostrum.Api.get_channel(channel_id), state}
  end

  defp via_tuple(name) do
    DiscordBot.Via.region_name(name)
  end
end
