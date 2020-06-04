defmodule Pager.InvalidCursor do
  @enforce_keys [:key]
  defexception @enforce_keys

  def new(key), do: %Pager.InvalidCursor{key: key}

  def message(val), do: "Invalid #{val.key} cursor"

end
