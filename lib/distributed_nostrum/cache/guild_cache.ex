defmodule DistributedNostrum.Cache.GuildCache do
  @moduledoc """
  See module doc for `DistributedNostrum.Bot` as this serves the same purpose for Nostrum's GuildCache process
  """
  use GenServer

  alias Nostrum.Cache.GuildCache
  alias Nostrum.Struct.Guild

  require Logger

  # INIT

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, [init_args], name: via_tuple(__MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, :initial_state}
  end

  # Client

  @spec get(Guild.id()) :: {:ok, Guild.t()} | {:error, GuildCache.reason()}
  def get(id) do
    GenServer.call(via_tuple(__MODULE__), {:get, id})
  end

  @spec select(Guild.id(), GuildCache.selector()) :: {:ok, any} | {:error, GuildCache.reason()}
  def select(id, selector) do
    GenServer.call(via_tuple(__MODULE__), {:select, id, selector})
  end

  @spec get_guilds(MapSet.t(Guild.id()), {module, atom, [any]}) :: Map.t()
  def get_guilds(guild_ids, mfa) do
    GenServer.call(via_tuple(__MODULE__), {:get_guilds, guild_ids, mfa})
  end

  @spec select_mfa(Guild.id(), {module(), atom(), [any()]}) ::
          {:ok, any} | {:error, GuildCache.reason()}
  def select_mfa(id, mfa) do
    GenServer.call(via_tuple(__MODULE__), {:select_mfa, id, mfa})
  end

  # Callbacks

  @impl GenServer
  def handle_call({:get, id}, _from, state) do
    {:reply, GuildCache.get(id), state}
  end

  @impl GenServer
  def handle_call({:select, id, selector}, _from, state) do
    {:reply, GuildCache.select(id, selector), state}
  end

  @impl GenServer
  def handle_call({:select_mfa, id, mfa}, _from, state) do
    {:reply, GuildCache.select_mfa(id, mfa), state}
  end

  @impl GenServer
  def handle_call({:get_guilds, guild_ids, mfa}, _from, state) do
    {:reply, GuildCache.get_guilds(guild_ids, mfa), state}
  end

  # Helpers

  defp via_tuple(name) do
    DiscordBot.Via.region_name(name)
  end
end
