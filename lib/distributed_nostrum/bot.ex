defmodule DistributedNostrum.Bot do
  @moduledoc """
  Genserver started on the same node as the Nostrum app and used as a passthrough for API calls to Nostrum. It is responsible for starting the Nostrum App (and thus the bunch of processes it spawns like shards, caches, gen stages...).

  We use this passthrough because we want to reach Nostrum processes from anywhere in the cluster, but Nostrum doesn't assign a global name to its processes. By giving a name to this specific Genserver, we can reach it from anywhere. Since it lives on the same node as the Nostrum processes, it can then pass the API calls to the local Nostrum Api process.
  """
  use GenServer
  use Bitwise

  import DistributedNostrum.Helpers

  alias DistributedNostrum.Cache.GuildCache
  alias DistributedNostrum.Member
  alias Nostrum.Api
  alias Nostrum.Struct.AuditLogEntry
  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.Guild
  alias Nostrum.Struct.Guild.Role
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User

  require Logger

  @type member_voice_state :: map
  @type member_voice_states :: map
  @type members :: %{Member.id() => Member.t()}
  @type voice_id :: integer()

  # INIT
  def start_link(init_args) do
    GenServer.start_link(__MODULE__, [init_args], name: via_tuple(__MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, :initial_state}
  end

  # Client
  def get_member_permissions(guild_id, member_id) do
    case GuildCache.select_mfa(
           guild_id,
           {__MODULE__, :extract_member_permissions_from_cache, [member_id]}
         ) do
      {:ok, result} ->
        result

      {:error, err} ->
        Logger.error("error: #{inspect(err)}")
        %{}
    end
  end

  def extract_member_permissions_from_cache(%Guild{members: members} = guild, member_id) do
    case Map.get(members, member_id) do
      nil ->
        nil

      %{roles: roles} = member ->
        %{
          permissions: Nostrum.Struct.Guild.Member.guild_permissions(member, guild),
          roles: roles
        }
    end
  end

  def get_all_members(guild_id) do
    case GuildCache.select_mfa(
           guild_id,
           {__MODULE__, :extract_all_members_from_cache, []}
         ) do
      {:ok, members} ->
        members

      {:error, err} ->
        Logger.error("error: #{inspect(err)}")
        %{}
    end
  end

  def extract_all_members_from_cache(%Guild{members: members} = _guild) do
    members
  end

  def get_all_channels(guild_id) do
    case GuildCache.select_mfa(
           guild_id,
           {__MODULE__, :extract_channels_from_cache, []}
         ) do
      {:ok, channels} ->
        channels

      {:error, err} ->
        Logger.error("error: #{inspect(err)}")
        %{}
    end
  end

  def extract_channels_from_cache(%Guild{channels: channels}) do
    channels
  end

  def extract_voice_states(guild) do
    guild.voice_states
  end

  @doc """
  Fetch all voice states in the voice channel specified by `guild_id` and `voice_channel_id`.
  """
  @spec fetch_voice_states_in_channel(Guild.id(), Channel.id()) ::
          {:ok, member_voice_states()} | {:error, term()}
  def fetch_voice_states_in_channel(guild_id, voice_channel_id) do
    with {:ok, voice_states} <-
           GuildCache.select_mfa(guild_id, {__MODULE__, :extract_voice_states, []}) do
      channel_voice_states =
        voice_states
        |> Stream.filter(fn vs -> vs.channel_id == voice_channel_id end)
        |> Stream.scan(Map.new(), fn vs, acc -> Map.put(acc, vs.user_id, vs) end)
        |> Enum.at(-1, Map.new())

      {:ok, channel_voice_states}
    end
  end

  @spec get_guilds(MapSet.t(Guild.id())) :: Map.t()
  def get_guilds(guild_ids) do
    GuildCache.get_guilds(guild_ids, {__MODULE__, :extract_display_info_from_guild, []})
  end

  def extract_display_info_from_guild(guild) do
    %{id: guild.id, name: guild.name, icon: guild.icon}
  end

  @doc """
  Augment every member of `members` with their voice state (if present in `voice_states`).
  """
  @spec merge_voice_state_to_members(members(), member_voice_states()) :: members()
  def merge_voice_state_to_members(members, voice_states) do
    Enum.reduce(
      members,
      Map.new(),
      fn {user_id, member}, acc ->
        member_voice_state = Map.get(voice_states, user_id, Map.new())

        member =
          member
          |> Member.populate_avatar_url()
          |> Map.merge(Member.from_voice_state(member_voice_state))

        Map.put(acc, user_id, member)
      end
    )
  end

  @doc """
  Get all members in the provided voice channels.
  """
  @spec get_members_in_voice_channels(Guild.id(), [Channel.id()]) ::
          {:ok, %{Member.id() => Member.t()}}
  def get_members_in_voice_channels(
        guild_id,
        voice_channel_ids
      )
      when is_list(voice_channel_ids) do
    result =
      Enum.reduce_while(voice_channel_ids, %{}, fn voice_channel_id, acc ->
        case fetch_voice_states_in_channel(guild_id, voice_channel_id) do
          {:ok, channel_voice_states} ->
            members_set = MapSet.new(Map.keys(channel_voice_states))

            members = fetch_members_in_set(members_set, guild_id)

            members_with_voice_states =
              merge_voice_state_to_members(members, channel_voice_states)

            {:cont, Map.merge(acc, members_with_voice_states)}

          {:error, err} ->
            {:halt, {:error, err}}
        end
      end)

    if match?({:error, _err}, result) do
      result
    else
      {:ok, result}
    end
  end

  @doc """
  Extract some member attributes from the guild genserver's cache for each member in the `members_set`.
  Only specific attributes of the Nostrum Member type are retrieved here in order to limit the size of the payload between the caller and the genserver containing the guild's cache.
  """
  @spec fetch_members_in_set(MapSet.t(User.id()), Guild.id()) :: members()
  def fetch_members_in_set(members_set, guild_id) do
    with {:ok, members} <-
           GuildCache.select_mfa(
             guild_id,
             {__MODULE__, :extract_members_from_cache, [members_set]}
           ) do
      members
    else
      _else -> %{}
    end
  end

  @doc """
  Fetch the voice state of the member specified by `guild_id` and `member_id`.
  """
  @spec fetch_member_voice_state(Guild.id(), Member.id()) :: member_voice_state() | nil
  def fetch_member_voice_state(guild_id, member_id) do
    case GuildCache.select_mfa(guild_id, {__MODULE__, :find_member_voice_state, [member_id]}) do
      {:ok, member_voice_state} ->
        member_voice_state

      _not_found ->
        nil
    end
  end

  def find_member_voice_state(guild, member_id) do
    Enum.find(guild.voice_states, fn vs -> vs.user_id == member_id end)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  def extract_members_from_cache(%Guild{members: members}, members_set) do
    members
    |> Stream.filter(fn {user_id, _member} -> MapSet.member?(members_set, user_id) end)
    |> Stream.scan(Map.new(), fn {user_id,
                                  %Guild.Member{
                                    nick: nick,
                                    user: %User{
                                      avatar: avatar,
                                      username: username,
                                      discriminator: discriminator
                                    }
                                  }},
                                 acc ->
      Map.put(acc, user_id, %Member{
        id: user_id,
        nick: nick || username,
        username: username,
        avatar_id: avatar,
        discriminator: String.to_integer(discriminator)
      })
    end)
    |> Enum.at(-1, Map.new())
  end

  @doc """
  Move given members to the voice channel with ID `voice_id`.
  """
  @dialyzer {:no_match, move_members: 4}
  @spec move_members(Guild.id(), [Member.id()], voice_id(), timeout()) :: :ok | {:error, term()}
  def move_members(guild_id, member_ids, voice_id, timeout \\ 30_000) do
    # Will only return the last error seen. All other moves will still be executed if possible.
    Enum.reduce(member_ids, :ok, fn member_id, acc ->
      case modify_guild_member(guild_id, member_id, [channel_id: voice_id], timeout) do
        {:ok} -> acc
        {:ok, _result} -> acc
        {:error, %Nostrum.Error.ApiError{status_code: 404}} -> acc
        {:error, err} -> {:error, err}
      end
    end)
  end

  @spec assign_roles_to_members(any, maybe_improper_list, maybe_improper_list, any) :: :ok
  @doc """
  Add given roles to given members.
  """
  def assign_roles_to_members(guild_id, member_ids, role_ids, timeout)
      when is_list(member_ids) and is_list(role_ids) do
    Enum.each(member_ids, fn member_id ->
      Enum.each(role_ids, fn role_id ->
        add_guild_member_role(guild_id, member_id, role_id, timeout)
      end)
    end)
  end

  def create_category(guild_id, opts, timeout \\ 5000) do
    opts = Keyword.put(opts, :type, channel_type(:category))
    create_guild_channel(guild_id, opts, timeout)
  end

  def create_voice_channel(guild_id, opts, timeout \\ 5000) do
    opts = Keyword.put(opts, :type, channel_type(:voice))
    create_guild_channel(guild_id, opts, timeout)
  end

  @spec create_guild_role(Guild.id(), Api.options(), AuditLogEntry.reason()) ::
          Api.error() | {:ok, Role.t()}
  def create_guild_role(guild_id, options, reason \\ nil, timeout \\ 5000) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:create_guild_role, guild_id, options, reason},
      timeout
    )
  end

  @spec create_dm(Member.id()) :: Api.error() | {:ok, Channel.dm_channel()}
  def create_dm(member_id, timeout \\ 5000) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:create_dm, member_id},
      timeout
    )
  end

  @spec create_message(Channel.id(), keyword() | map() | String.t(), integer()) ::
          Api.error() | {:ok, Message.t()}
  def create_message(channel_id, opts, timeout \\ 5000) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:create_message, channel_id, opts},
      timeout
    )
  end

  @spec modify_guild_role_positions(
          Guild.id(),
          [%{id: Role.id(), position: integer()}],
          String.t() | nil
        ) :: {:error, term()} | {:ok, [Role.t()]}
  def modify_guild_role_positions(guild_id, positions, reason \\ nil, timeout \\ 5000) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:modify_guild_role_positions, guild_id, guild_id, positions, reason},
      timeout
    )
  end

  @spec modify_guild_member(Guild.id(), User.id(), Api.options()) :: Api.error() | {:ok}
  def modify_guild_member(guild_id, member_id, options \\ %{}, timeout \\ 30_000) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:modify_guild_member, guild_id, member_id, options},
      timeout
    )
  end

  @spec delete_channels([Channel.id()], AuditLogEntry.reason()) :: :ok
  def delete_channels(channel_ids, reason \\ nil, timeout \\ 5000)

  def delete_channels(channel_ids, reason, timeout) when is_list(channel_ids) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:delete_channels, channel_ids, reason},
      timeout
    )
  end

  def delete_channels(_channel_ids, _reason, _timeout) do
    :ok
  end

  @spec delete_guild_roles(Guild.id(), [Role.id()], AuditLogEntry.reason()) :: :ok
  def delete_guild_roles(guild_id, role_ids, reason \\ nil, timeout \\ 5000)

  def delete_guild_roles(guild_id, role_ids, reason, timeout) when is_list(role_ids) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:delete_guild_roles, guild_id, role_ids, reason},
      timeout
    )
  end

  def delete_guild_roles(_guild_id, _guild_ids, _reason, _timeout) do
    :ok
  end

  @spec add_guild_member_role(integer(), integer(), integer(), AuditLogEntry.reason()) ::
          {:error, Api.error()} | :ok
  def add_guild_member_role(guild_id, member_id, role_id, reason \\ nil, timeout \\ 5000) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:add_guild_member_role, guild_id, member_id, role_id, reason},
      timeout
    )
  end

  @spec create_guild_channel(Guild.id(), Api.options()) ::
          Api.error() | {:ok, Channel.guild_channel()}
  def create_guild_channel(guild_id, options, timeout \\ 5000) do
    GenServer.call(
      via_tuple(__MODULE__),
      {:create_guild_channel, guild_id, options},
      timeout
    )
  end

  # Server

  @impl GenServer
  def handle_call({:create_guild_role, guild_id, options, reason}, _from, state) do
    {:reply, Api.create_guild_role(guild_id, options, reason), state}
  end

  @impl GenServer
  def handle_call({:create_dm, user_id}, _from, state) do
    {:reply, Api.create_dm(user_id), state}
  end

  @impl GenServer
  def handle_call({:create_message, channel_id, opts}, _from, state) do
    {:reply, Api.create_message(channel_id, opts), state}
  end

  @impl GenServer
  def handle_call({:modify_guild_role_positions, guild_id, positions, reason}, _from, state) do
    {:reply, Api.modify_guild_role_positions(guild_id, positions, reason), state}
  end

  @impl GenServer
  def handle_call({:modify_guild_member, guild_id, member_id, options}, _from, state) do
    {:reply, Api.modify_guild_member(guild_id, member_id, options), state}
  end

  @impl GenServer
  def handle_call({:delete_channels, channel_ids, reason}, _from, state) do
    {:reply, do_delete_channels(channel_ids, reason), state}
  end

  @impl GenServer
  def handle_call({:delete_guild_roles, guild_id, role_ids, reason}, _from, state) do
    {:reply, do_delete_guild_roles(guild_id, role_ids, reason), state}
  end

  @impl GenServer
  def handle_call({:add_guild_member_role, guild_id, member_id, role_id, reason}, _from, state) do
    case Api.add_guild_member_role(guild_id, member_id, role_id, reason) do
      {:ok} ->
        {:reply, :ok, state}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call({:create_guild_channel, guild_id, options}, _from, state) do
    {:reply, Api.create_guild_channel(guild_id, options), state}
  end

  # DOERS

  @dialyzer {:no_match, do_delete_channels: 2}
  defp do_delete_channels(channel_ids, reason) do
    Enum.reduce_while(channel_ids, :ok, fn channel_id, _acc ->
      case Api.delete_channel(channel_id, reason) do
        {:ok, _channel} -> {:cont, :ok}
        # 404s are fine
        {:error, %Nostrum.Error.ApiError{status_code: 404}} -> {:cont, :ok}
        {:error, err} -> {:halt, {:error, err}}
      end
    end)
  end

  @dialyzer {:no_match, do_delete_guild_roles: 3}
  defp do_delete_guild_roles(guild_id, role_ids, reason) do
    Enum.reduce_while(role_ids, :ok, fn role_id, _acc ->
      case Api.delete_guild_role(guild_id, role_id, reason) do
        {:ok} -> {:cont, :ok}
        # 404s are fine
        {:error, %Nostrum.Error.ApiError{status_code: 404}} -> {:cont, :ok}
        {:error, err} -> {:halt, {:error, err}}
      end
    end)
  end

  # HELPERS

  @doc """
  Get the bot client ID (also its Discord ID).
  """
  def get_bot_id do
    Application.get_env(:discord_bot, :distributed_nostrum)[:bot_id]
  end

  defp via_tuple(name) do
    DiscordBot.Via.region_name(name)
  end
end
