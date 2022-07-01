defmodule DistributedNostrum.Member do
  use Accessible
  use Bitwise

  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.User

  require Logger

  @type id :: User.id()
  @type url :: String.t()
  @type channel_id :: Channel.id()

  @required_fields ~w(id nick username avatar_id discriminator)a
  @optional_fields ~w(avatar_url mute? deaf? channel_id)a

  @enforce_keys @required_fields
  defstruct @required_fields ++ @optional_fields

  @type t :: %__MODULE__{
          id: id(),
          nick: String.t(),
          username: String.t(),
          avatar_id: String.t(),
          avatar_url: url(),
          discriminator: integer(),
          mute?: boolean(),
          deaf?: boolean(),
          channel_id: channel_id()
        }

  def from_voice_state(%{
        channel_id: channel_id,
        mute: mute,
        self_mute: self_mute,
        deaf: deaf,
        self_deaf: self_deaf,
        member:
          %{
            user: %{
              avatar: avatar_id,
              discriminator: discriminator_str,
              id: id,
              username: username
            }
          } = vs_member
      }) do
    member = %__MODULE__{
      id: id,
      mute?: self_mute || mute,
      deaf?: self_deaf || deaf,
      channel_id: channel_id,
      nick: Map.get(vs_member, :nick, username) || username,
      avatar_id: avatar_id,
      username: username,
      discriminator: String.to_integer(discriminator_str)
    }

    populate_avatar_url(member)
  end

  def from_voice_state(%{
        channel_id: channel_id,
        deaf: deaf,
        mute: mute,
        self_deaf: self_deaf,
        self_mute: self_mute
      }) do
    %{
      channel_id: channel_id,
      deaf?: self_deaf || deaf,
      mute?: self_mute || mute
    }
  end

  def attrs_from_nostrum_member(%Nostrum.Struct.Guild.Member{
        user: %User{
          avatar: avatar_id,
          discriminator: discriminator_str,
          id: id,
          username: username
        },
        # roles: roles,
        deaf: deaf,
        mute: mute,
        nick: nick
      }) do
    %{
      id: id,
      mute?: mute,
      deaf?: deaf,
      nick: nick,
      avatar_id: avatar_id,
      username: username,
      discriminator: discriminator_str
    }
    |> populate_nick()
    |> populate_discriminator()
    |> populate_avatar_url()
  end

  def update(%__MODULE__{} = member, attrs) do
    member
    |> Map.merge(attrs)
    |> populate_discriminator()
    |> populate_nick()
    |> populate_avatar_url()
  end

  def populate_discriminator(%{discriminator: discriminator_str} = member)
      when is_binary(discriminator_str) do
    Map.put(member, :discriminator, String.to_integer(discriminator_str))
  end

  def populate_discriminator(%{discriminator: discriminator} = member)
      when is_integer(discriminator) do
    member
  end

  def populate_nick(%{nick: nick, username: username} = member) do
    Map.put(member, :nick, nick || username)
  end

  def populate_avatar_url(
        %{id: user_id, avatar_id: avatar_id, discriminator: discriminator} = member
      ) do
    avatar_url =
      if avatar_id != nil do
        "https://cdn.discordapp.com/avatars/#{user_id}/#{avatar_id}.png"
      else
        "https://cdn.discordapp.com/embed/avatars/#{rem(discriminator, 5)}.png"
      end

    Map.put(member, :avatar_url, avatar_url)
  end
end
