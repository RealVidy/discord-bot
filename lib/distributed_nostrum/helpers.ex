defmodule DistributedNostrum.Helpers do
  def to_channel_type_atom(0) do
    :text
  end

  def to_channel_type_atom(1) do
    :dm
  end

  def to_channel_type_atom(2) do
    :voice
  end

  def to_channel_type_atom(3) do
    :group_dm
  end

  def to_channel_type_atom(4) do
    :category
  end

  def to_channel_type_atom(5) do
    :news
  end

  def to_channel_type_atom(6) do
    :store
  end

  def to_channel_type_atom(10) do
    :news_thread
  end

  def to_channel_type_atom(11) do
    :public_thread
  end

  def to_channel_type_atom(12) do
    :private_thread
  end

  def to_channel_type_atom(13) do
    :stage_voice
  end

  def to_channel_type_atom(_other) do
    :text
  end

  defmacro channel_type(:text) do
    quote do
      0
    end
  end

  defmacro channel_type(:dm) do
    quote do
      1
    end
  end

  defmacro channel_type(:voice) do
    quote do
      2
    end
  end

  defmacro channel_type(:group_dm) do
    quote do
      3
    end
  end

  defmacro channel_type(:category) do
    quote do
      4
    end
  end

  defmacro channel_type(:news) do
    quote do
      5
    end
  end

  defmacro channel_type(:store) do
    quote do
      6
    end
  end

  defmacro channel_type(:news_thread) do
    quote do
      10
    end
  end

  defmacro channel_type(:public_thread) do
    quote do
      11
    end
  end

  defmacro channel_type(:private_thread) do
    quote do
      12
    end
  end

  defmacro channel_type(:stage_voice) do
    quote do
      13
    end
  end

  defmacro channel_type(_other) do
    quote do
      0
    end
  end
end
