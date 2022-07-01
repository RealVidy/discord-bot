defmodule DistributedNostrum.DM do
  use Bitwise

  alias DistributedNostrum.Member
  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User

  require Logger

  @type dm_id :: Message.id()
  @type channel_id :: Channel.id()
  @type member_id :: Member.id()

  @required_fields ~w(dm_id author_id channel_id content)a
  @optional_fields ~w(reactions)a

  @enforce_keys @required_fields
  defstruct @required_fields ++ @optional_fields

  @type t :: %__MODULE__{
          dm_id: dm_id(),
          author_id: member_id(),
          channel_id: channel_id(),
          content: String.t(),
          reactions: [any()]
        }

  def from_message_create(%Message{
        author: %User{
          id: author_id
        },
        channel_id: channel_id,
        content: content,
        id: dm_id,
        reactions: reactions
      }) do
    %__MODULE__{
      dm_id: dm_id,
      author_id: author_id,
      channel_id: channel_id,
      content: content,
      reactions: reactions
    }
  end

  def from_message_create(msg) do
    Logger.warn("Failure to create DM from message #{inspect(msg,
    pretty: true,
    structs: true,
    syntax_colors: [number: :magenta, atom: :cyan, string: :yellow, boolean: :blue, nil: :magenta],
    limit: :infinity)}\n")

    nil
  end
end
