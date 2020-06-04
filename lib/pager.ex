defmodule Pager do
  @moduledoc """
  Pager is a library for adding cursor-based pagination to Ecto. It
  provides an efficient means of paginating through a resultset, but
  it requires some buy-in to take advantage of.

  In the cursor model, each record in the resultset has an associated
  'cursor', a value that represents its position within the ordered
  resultset. By using an object's cursor, we can ask for results
  before or after a given result.

  ## Use

  Let us say we wish to paginate a list of users. To make it easy, we
  shall have a serial primary key, only a single database node and be
  querying by order of signup.

  Our cursor format will be: `[user.id]`. Because it is a primary key,
  it is unique and because it is a serial and we only have one database
  node, it will naturally encode the order of signup.

  ```elixir
  defmodule Example do

    import Ecto.Query

    def pager() do
      %Pager{
        cursor_generator: &[&1.id],
        cursor_validator: &is_integer/1,
        default_limit: 25, # When the user doesn't provide a limit
        max_limit: 100, # Can't go higher than this
        min_limit: 1, # Can't go lower than this
        overflow: :saturate, # When you go higher, pin it at the maximum
        underflow: :saturate, # When you go lower, pin it at the minimum
      }
    end

    def list_users(options) do
      with {:ok, opts} <- Pager.cast(options, pager()) do

      end
    end
  end
  ```


  ## Cursors in detail

  A cursor is a list of field values for a record. The structure of
  the cursor is a property of the page, that is to say cursors for a
  page should be generated from the same fields used in the `order`
  clause of your query, in the order they are used.

  Cursors must be unique in a resultset in order to ensure pagination
  works reliably. For example if you sort users by followers, it's
  quite conceivable that many users will have the same number of
  followers, particularly when that number is low. By sorting by an
  additional unique column, you create a total ordering which allows
  pagination to always work reliably.
  """

  alias Pager.InvalidCursor

  @enforce_keys [:cursor_generator, :cursor_validator]
  defstruct [
    :cursor_generator,
    :cursor_validator,
    :default_limit,
    :max_limit,
    :min_limit,
    :overflow,
    :underflow,
  ]

  @type cursor :: [term]

  @type page_opts :: %{
    optional(:after) => cursor,
    optional(:before) => cursor,
    optional(:limit) => non_neg_integer,
  }

  @type processed_page_opts :: %{
    required(:limit) => non_neg_integer,
    optional(:after) => cursor,
    optional(:before) => cursor,
  }

  @type cursor_generator :: (term -> cursor)

  @type cursor_validator :: (cursor -> boolean)

  @type t :: %Pager{
    cursor_generator: cursor_generator,
    cursor_validator: cursor_validator,
    default_limit: pos_integer | nil,
    max_limit: pos_integer | nil,
    min_limit: pos_integer | nil,
    overflow: :saturate | :default | nil,
    underflow: :saturate | :default | nil,
  }

  @default_limit 25
  @max_limit 100
  @min_limit 1
  @underflow :saturate
  @overflow :saturate

  @doc "Given a list of keys and a record, generate a cursor"
  def generate_cursor(keys, data), do: Enum.map(keys, &Map.fetch!(data, &1))

  @doc "Given a cursor and a list of predicates, does the cursor pass?"
  def validate_cursor(cursor, tests)
  def validate_cursor([], []), do: true
  def validate_cursor([], _), do: false
  def validate_cursor(_, []), do: false
  def validate_cursor([c|cs], [t|ts]), do: t.(c) and validate_cursor(cs, ts)

  @doc """
  Casts paging options on pages where we respect both limits and
  before/after cursors.
  """
  @spec cast(page_opts, Pager.t) :: {:ok, processed_page_opts} | {:error, term}
  def cast(opts, %Pager{cursor_validator: v}=pager) when is_function(v, 1) do
    case opts do
      %{after: a} -> cast_relative(opts, pager, :after, a)
      %{before: b} -> cast_relative(opts, pager, :before, b)
      %{} -> {:ok, cast_limit(opts, opts)}
    end
  end

  defp cast_relative(opts, pager, key, val) do
    if pager.cursor_validator.(val),
      do: {:ok, Map.put(cast_limit(opts, pager), key, val)},
      else: {:error, InvalidCursor.new(key)}
  end

  @doc """
  Casts paging options on pages where we only respect limits, such
  as in multi-parent batched graphql queries.
  """
  @spec cast_limit(page_opts, Pager.t) :: %{limit: pos_integer}
  def cast_limit(opts, %Pager{}=pager) do
    default = option(pager, :default_limit, @default_limit)
    limit = option(opts, :limit, default)
    max = option(pager, :max_limit, @max_limit)
    min = option(pager, :min_limit, @min_limit)
    underflow = option(pager, :underflow, @underflow)
    overflow = option(pager, :overflow, @overflow)
    cond do
      limit > max and overflow == :default -> %{limit: default}
      limit > max -> %{limit: max}
      limit < min and underflow == :default -> %{limit: default}
      limit < min -> %{limit: min}
      true -> %{limit: limit}
    end
  end

  # retrieve a key from the options, or config, or use a fallback
  defp option(options, key, fallback), do: options[key] || config(key, fallback)

  # retrieve a key from this app's config
  defp config(key, default), do: Application.get_env(:pager, key, default)

  @doc """
  The number of rows an ecto query should select. Expects a map as
  given by either of `cast/2` or `cast_limit/2`.
  """
  @spec ecto_limit(processed_page_opts) :: non_neg_integer
  def ecto_limit(%{limit: l, after: _}), do: l + 2
  def ecto_limit(%{limit: l, before: _}), do: l + 2
  def ecto_limit(%{limit: l}), do: l + 1

end
