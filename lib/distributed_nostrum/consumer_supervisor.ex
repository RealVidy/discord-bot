defmodule DistributedNostrum.ConsumerSupervisor do
  @moduledoc """
  Spawns one consumer per online scheduler at startup,
  which means one consumer per CPU core in the default ERTS settings.

  This module is meant to be started on the same node as the Nostrum App. If it is on another node in the cluster, it won't receive events from its Nostrum producers.
  """

  use Supervisor

  alias DistributedNostrum.Consumer

  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children =
      for n <- 1..System.schedulers_online(),
          do: Supervisor.child_spec({Consumer, []}, id: {:bot, :consumer, n})

    Supervisor.init(children, strategy: :one_for_one)
  end
end
