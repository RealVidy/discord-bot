defmodule DistributedNostrum.Guild do
  @type guild :: struct()
  @type member_id :: integer()
  @type member :: struct()

  @spec get_member(guild(), member_id()) :: {:ok, member()} | {:error, :not_found}
  def get_member(guild, member_id) do
    case Map.get(guild.members, member_id) do
      nil -> {:error, :not_found}
      member -> {:ok, member}
    end
  end
end
