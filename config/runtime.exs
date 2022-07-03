import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Start the phoenix server if environment is set and running in a release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :discord_bot, DiscordBotWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "nara-discord-bot.fly.dev"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :discord_bot, DiscordBotWeb.Endpoint,
    url: [host: host, port: 80],
    http: [
      port: port,
      # IMPORTANT: support IPv6 addresses
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: secret_key_base

  config :libcluster,
    debug: true,
    topologies: [
      discord_bot: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          # default is 5_000
          # polling_interval: 5_000,
          query: "nara-discord-bot.internal",
          node_basename: "nara-discord-bot"
        ]
      ],
      nara_secondary: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          # default is 5_000
          # polling_interval: 5_000,
          query: "nara-secondary.internal",
          node_basename: "nara-secondary"
        ]
      ]
    ]

  discord_bot_token =
    System.get_env("DISCORD_BOT_TOKEN") ||
      raise "DISCORD_BOT_TOKEN not available"

  # Maybe set fullsweep_after_default to save memory vs CPU
  # https://hexdocs.pm/nostrum/intro.html
  config :nostrum,
    token: discord_bot_token

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :discord_bot, DiscordBotWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
end

config :logger, :console,
  level: String.to_existing_atom(System.get_env("LOG_LEVEL", "error")),
  format: "$message [$metadata]\n",
  truncate: :infinity,
  colors: [enabled: true],
  metadata: [:mfa]

config :discord_bot, :distributed_nostrum,
  required_bot_perms: 285_232_144,
  bot_id: String.to_integer(System.get_env("DISCORD_CLIENT_ID", "0"))

config :discord_bot,
  current_region: System.fetch_env!("FLY_REGION"),
  current_app: System.fetch_env!("FLY_APP_NAME")
