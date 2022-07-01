defmodule DistributedNostrum.Consumer do
  use Nostrum.Consumer

  import DistributedNostrum.Helpers

  alias DistributedNostrum.DM
  alias DistributedNostrum.Member
  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.Event.MessageDelete
  alias Nostrum.Struct.Guild
  alias Nostrum.Struct.Guild.Role
  alias Nostrum.Struct.Message

  require Logger

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event(event) do
    process_event(event)
  end

  defp process_event({:VOICE_STATE_UPDATE, %{guild_id: guild_id} = voice_state, _ws}) do
    broadcast_to_guild(guild_id, {:VOICE_STATE_UPDATE, Member.from_voice_state(voice_state)})
  end

  defp process_event(
         {:GUILD_MEMBER_UPDATE, {guild_id, _before, %Guild.Member{} = new_member}, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:GUILD_MEMBER_UPDATE, Member.attrs_from_nostrum_member(new_member)}
    )
  end

  defp process_event({:GUILD_MEMBER_UPDATE, {_before, _new_member}, _ws}) do
    # Triggered when bot removed from guild. I don't know when else.
    :noop
  end

  defp process_event({:GUILD_MEMBER_UPDATE, _event, _ws}) do
    :noop
  end

  defp process_event({:GUILD_MEMBER_ADD, {guild_id, added_member}, _ws}) do
    broadcast_to_guild(
      guild_id,
      {:GUILD_MEMBER_ADD, Member.attrs_from_nostrum_member(added_member)}
    )
  end

  defp process_event({:GUILD_MEMBER_ADD, _payload, _ws}) do
    :noop
  end

  defp process_event({:GUILD_MEMBER_REMOVE, {guild_id, removed_member}, _ws}) do
    broadcast_to_guild(
      guild_id,
      {:GUILD_MEMBER_REMOVE, Member.attrs_from_nostrum_member(removed_member)}
    )
  end

  defp process_event({:GUILD_MEMBER_REMOVE, _payload, _ws}) do
    :noop
  end

  defp process_event({:CHANNEL_PINS_UPDATE, _payload, _ws}) do
    :noop
  end

  defp process_event(
         {:CHANNEL_UPDATE,
          {
            _before,
            %Channel{
              guild_id: guild_id,
              type: channel_type(:voice)
            } = updated_channel
          }, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:VOICE_CHANNEL_UPDATE, updated_channel}
    )
  end

  defp process_event(
         {:CHANNEL_UPDATE,
          {_old_channel,
           %Channel{
             guild_id: guild_id,
             type: channel_type(:text)
           } = updated_channel}, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:TEXT_CHANNEL_UPDATE, updated_channel}
    )
  end

  defp process_event(
         {:CHANNEL_UPDATE,
          {_old_channel,
           %Channel{
             guild_id: guild_id,
             type: channel_type(:category)
           } = updated_category}, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:CATEGORY_UPDATE, updated_category}
    )
  end

  defp process_event(
         {:CHANNEL_CREATE,
          %Channel{
            guild_id: guild_id,
            type: channel_type(:voice)
          } = channel, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:VOICE_CHANNEL_CREATE, channel}
    )
  end

  defp process_event(
         {:CHANNEL_CREATE,
          %{
            id: channel_id,
            recipients: [
              %{
                id: member_id
              }
            ],
            type: channel_type(:dm)
          }, _ws}
       ) do
    broadcast_to_chat(channel_id, {:NEW_DM_CHANNEL, member_id})
  end

  defp process_event({:CHANNEL_CREATE, %Channel{type: channel_type(:group_dm)} = group_dm, _ws}) do
    Logger.info("RECEIVED IN DISTRIBUTED NOSTRUM group_dm #{inspect(group_dm,
    pretty: true,
    structs: true,
    syntax_colors: [number: :magenta, atom: :cyan, string: :yellow, boolean: :blue, nil: :magenta],
    limit: :infinity)}\n")
  end

  defp process_event(
         {:CHANNEL_CREATE,
          %Channel{
            guild_id: guild_id,
            type: channel_type(:category)
          } = channel, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:CATEGORY_CREATE, channel}
    )
  end

  defp process_event(
         {:CHANNEL_CREATE,
          %Channel{
            guild_id: _guild_id,
            type: channel_type(:text)
          } = _channel, _ws}
       ) do
    # broadcast_to_guild(
    #   guild_id,
    #   {:TEXT_CHANNEL_CREATE, channel}
    # )
    :noop
  end

  defp process_event(
         {:CHANNEL_DELETE,
          %Channel{
            guild_id: guild_id,
            id: channel_id,
            type: channel_type(:voice)
          }, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:VOICE_CHANNEL_DELETE, channel_id}
    )
  end

  defp process_event(
         {:CHANNEL_DELETE,
          %Channel{
            guild_id: guild_id,
            id: channel_id,
            type: channel_type(:category)
          }, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:CATEGORY_DELETE, channel_id}
    )
  end

  defp process_event(
         {:CHANNEL_DELETE,
          %Channel{
            id: channel_id,
            guild_id: guild_id,
            type: channel_type(:text)
          }, _ws}
       ) do
    broadcast_to_guild(
      guild_id,
      {:TEXT_CHANNEL_DELETE, channel_id}
    )
  end

  defp process_event({:GUILD_ROLE_CREATE, {guild_id, new_role}, _ws}) do
    broadcast_to_guild(
      guild_id,
      {:GUILD_ROLE_CREATE, new_role}
    )
  end

  defp process_event({:GUILD_ROLE_DELETE, {guild_id, %Role{id: role_id}}, _ws}) do
    broadcast_to_guild(
      guild_id,
      {:GUILD_ROLE_DELETE, role_id}
    )
  end

  defp process_event({:GUILD_ROLE_UPDATE, {guild_id, _old_role, updated_role}, _ws}) do
    broadcast_to_guild(
      guild_id,
      {:GUILD_ROLE_UPDATE, updated_role}
    )
  end

  defp process_event({:MESSAGE_CREATE,
        %Message{
          channel_id: channel_id,
          # I think the only way I can know that this is a DM is the fact that the guild_id is nil.
          guild_id: nil
          #  type: channel_type(:text) for some reason DMs with the bot have the type `:text`
        } = dm, _ws}) do
    message = DM.from_message_create(dm)

    if message != nil do
      broadcast_to_chat(
        channel_id,
        {:DM_CREATE, message}
      )
    end
  end

  defp process_event({:MESSAGE_UPDATE,
        %Message{
          channel_id: channel_id,
          # I think the only way I can know that this is a DM is the fact that the guild_id is nil.
          guild_id: nil
          #  type: channel_type(:text) for some reason DMs with the bot have the type `:text`
        } = dm, _ws}) do
    message = DM.from_message_create(dm)

    if message != nil do
      broadcast_to_chat(
        channel_id,
        {:DM_UPDATE, message}
      )
    end
  end

  defp process_event({:MESSAGE_DELETE, %MessageDelete{channel_id: nil}, _ws}) do
    :noop
  end

  defp process_event({:MESSAGE_DELETE,
        %MessageDelete{
          channel_id: channel_id,
          # I think the only way I can know that this is a DM being deleted is the fact that the guild_id is nil.
          guild_id: nil,
          id: message_id
        }, _ws}) do
    broadcast_to_chat(
      channel_id,
      {:DM_DELETE, message_id}
    )
  end

  defp process_event({:GUILD_AVAILABLE, %Nostrum.Struct.Guild{id: guild_id}, _ws}) do
    broadcast_to_guild(
      guild_id,
      :GUILD_AVAILABLE
    )
  end

  defp process_event({:GUILD_UNAVAILABLE, _msg, _ws}) do
    :noop
  end

  defp process_event({:PRESENCE_UPDATE, {_guild_id, _old_presence, _new_presence}, _ws}) do
    :noop
  end

  defp process_event({:READY, _msg, _ws}) do
    :ready
  end

  defp process_event({:RESUMED, _trace, _ws}) do
    :noop
  end

  defp process_event({:GUILD_CREATE, _new_guild, _ws}) do
    :noop
  end

  defp process_event({:GUILD_DELETE, _deleted_guild, _ws}) do
    # TODO: I may want to react to that one
    :noop
  end

  # Received when Nostrum's config contains `request_guild_members: true`.
  defp process_event({:GUILD_MEMBERS_CHUNK, %{guild_id: guild_id}, _ws}) do
    broadcast_to_guild(
      guild_id,
      :GUILD_MEMBERS_CHUNK
    )
  end

  defp process_event({:GUILD_APPLICATION_COMMAND_COUNTS_UPDATE, _payload, _ws}) do
    :noop
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  defp process_event(event) do
    Logger.info("UNHANDLED event in consumer #{inspect(event,
    pretty: true,
    structs: true,
    syntax_colors: [number: :magenta, atom: :cyan, string: :yellow, boolean: :blue, nil: :magenta],
    limit: :infinity)}\n")

    :noop
  end

  defp broadcast_to_chat(channel_id, msg) do
    GenServer.cast(via_tuple("discord_chat", channel_id), msg)
  end

  defp broadcast_to_guild(guild_id, msg) do
    GenServer.cast(via_tuple("discord_voice", guild_id), msg)
  end

  defp via_tuple(prefix, id) do
    {:via, Horde.Registry, {Nara.HordeRegistry, "#{prefix}##{id}"}}
  end
end
