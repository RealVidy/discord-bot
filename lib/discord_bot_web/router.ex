defmodule DiscordBotWeb.Router do
  use DiscordBotWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", DiscordBotWeb do
    pipe_through(:api)
  end
end
