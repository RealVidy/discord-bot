defmodule DiscordBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :discord_bot,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases(),
      default_release: :discord_bot
    ]
  end

  defp releases() do
    [
      discord_bot: [
        include_executables_for: [:unix],
        cookie: "FSnT8h0dVOCB2iUtn9mwjIWzEjnPTfjFpRLAqT6OhYliOrQqE1bsSg=="
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {DiscordBot.Application, []},
      extra_applications: [:logger, :runtime_tools],
      included_applications: [:nostrum]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:accessible, "~> 0.3.0"},
      {:cowlib, "~> 2.6", override: true},
      {:horde, git: "https://github.com/RealVidy/horde.git"},
      {:jason, "~> 1.2"},
      {:libcluster, "~> 3.3"},
      {:nostrum, git: "https://github.com/RealVidy/nostrum", runtime: false},
      {:phoenix, "~> 1.6.6"},
      {:plug_cowboy, "~> 2.5"},
      {:telemetry, "~> 1.0", override: true},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0", override: true}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
