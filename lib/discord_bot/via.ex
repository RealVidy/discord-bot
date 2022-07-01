defmodule DiscordBot.Via do
  require Logger

  def region_name(name) do
    current_region = Application.get_env(:discord_bot, :current_region)
    name = String.to_atom("#{current_region}_#{name}")
    Logger.info(" name #{inspect(name, pretty: true)}\n")
    {:via, Horde.Registry, {Nara.HordeRegistry, name}}
  end
end
