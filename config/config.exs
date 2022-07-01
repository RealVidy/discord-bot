# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :discord_bot, DiscordBotWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: DiscordBotWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: DiscordBot.PubSub,
  live_view: [signing_salt: "0DX6d7xr"]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :nostrum,
  token: System.get_env("DISCORD_BOT_TOKEN"),
  num_shards: :auto,
  request_guild_members: true,
  caches: %{
    presences: Nostrum.Cache.PresenceCache.NoOp
  },
  # log_full_events: true,
  gateway_intents: [
    :guilds,
    :guild_members,
    :guild_voice_states,
    :direct_messages,
    :direct_message_reactions
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
