defmodule DistributedNostrum.Starter do
  @moduledoc """
  Starter for all Nostrum related processes.
  It is meant to be started on a single node in the cluster (otherwise, each node would spawn a bot which would connect to Discord, build caches, react to events, etc. It would DDoS both Discord and ourselves).
  """
  use GenServer

  alias DistributedNostrum.Bot
  alias DistributedNostrum.Cache.ChannelCache
  alias DistributedNostrum.Cache.GuildCache
  alias DistributedNostrum.Api
  alias DistributedNostrum.ConsumerSupervisor

  require Logger

  def start_link(_init_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, :noop, {:continue, :start_nostrum_group}}
  end

  def handle_continue(:start_nostrum_group, state) do
    # Start all Nostrum processes.
    # QUESTION: Is this really how I should do it? It seems really ugly... I'd love to supervise
    # all of these but a supervisor will crash if they fail to start because of a name_conflict,
    # which happens on every node after the first one...
    with {:error, err} <- Application.ensure_all_started(:nostrum) do
      Logger.error("error: #{inspect(err, pretty: true)}")
    end

    ConsumerSupervisor.start_link([])
    GuildCache.start_link([])
    ChannelCache.start_link([])
    Bot.start_link([])
    Api.start_link([])

    {:noreply, state}
  end
end
