defmodule DistributedNostrum.Permissions do
  use Bitwise

  alias DistributedNostrum.Guild

  defdelegate all(), to: Nostrum.Permission
  defdelegate from_bitset(bitset), to: Nostrum.Permission
  defdelegate to_bit(permission), to: Nostrum.Permission
  defdelegate to_bitset(permissions), to: Nostrum.Permission

  defdelegate member_guild_permissions(member, guild),
    to: Nostrum.Struct.Guild.Member,
    as: :guild_permissions

  defdelegate member_channel_permissions(member, guild, channel_id),
    to: Nostrum.Struct.Guild.Member,
    as: :guild_channel_permissions

  @doc """
  Ensure that the given member has the required permissions in that guild.
  """
  def ensure_member_guild_permissions(guild, member_id, required_permissions) do
    with {:ok, member} <- Guild.get_member(guild, member_id),
         permissions <-
           member_guild_permissions(member, guild) do
      if validate_permissions(permissions, required_permissions) do
        :ok
      else
        {:error, :missing_permissions}
      end
    end
  end

  # Check if the `permission_overwrite` targets the member (TODO: or one of its roles) and contains *at least* the `required_perms_bitset` or is admin / owner.
  def validate_member_allowed(
        %{id: id, type: type, allow: allow, deny: deny} = _permission_overwrite,
        required_perms_bitset,
        member_id,
        member_roles,
        guild_id
      ) do
    cond do
      # Permission for this specific member
      id == member_id ->
        is_allowed(allow, deny, required_perms_bitset)

      # Permission for everyone (guild_id) or member roles
      type == 0 && (id == guild_id || id in member_roles) ->
        is_allowed(allow, deny, required_perms_bitset)

      true ->
        false
    end
  end

  def is_allowed(allow, deny, required_perms_bitset) do
    validate_permissions(allow, required_perms_bitset) ||
      not validate_permissions(deny, required_perms_bitset)
  end

  # Check if the `permissions` contain *at least* the `required_perms_bitset` or is admin / owner.
  def validate_permissions(permissions, required_perms_bitset)

  def validate_permissions(permissions, required_perms_bitset) when is_list(permissions) do
    permissions_bitset = to_bitset(permissions)
    validate_permissions(permissions_bitset, required_perms_bitset)
  end

  def validate_permissions(permissions_bitset, required_perms_bitset)
      when is_integer(permissions_bitset) do
    is_admin(permissions_bitset) or
      meets_requirement(permissions_bitset, required_perms_bitset)
  end

  defp meets_requirement(permissions_bitset, required_perms_bitset_bitset) do
    (permissions_bitset &&& required_perms_bitset_bitset) == required_perms_bitset_bitset
  end

  def is_admin(permissions) when is_integer(permissions) do
    admin_bit = to_bit(:administrator)
    (permissions &&& admin_bit) == admin_bit
  end

  @doc """
  Fetch the minimum bot permissions required to operate.
  """
  def required_bot_permissions do
    Application.get_env(:discord_bot, :distributed_nostrum)[:required_bot_perms]
  end
end
