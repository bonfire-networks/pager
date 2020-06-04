defmodule Pager.PageInfo do
  @moduledoc """
  Information about this page of results relative to the entire set of results:
  * Cursors for pagination
  * Whether there is a previous/next page
  """
  @enforce_keys [:start_cursor, :end_cursor, :has_previous_page, :has_next_page]
  defstruct @enforce_keys
  
  alias Pager.PageInfo

  @type opt_bool :: true | false | nil

  @type t :: %Pager.PageInfo{
    start_cursor: Pager.cursor | nil,
    end_cursor: Pager.cursor | nil,
    has_previous_page: opt_bool,
    has_next_page: opt_bool,
  }

  @doc "Create a new PageInfo from its constituents"
  @spec new(start_cursor :: term, end_cursor :: term, prev_page? :: opt_bool, next_page? :: opt_bool) :: t
  def new(start_cursor, end_cursor, prev_page?, next_page?) do
    %PageInfo{
      start_cursor: start_cursor,
      end_cursor: end_cursor,
      has_previous_page: prev_page?,
      has_next_page: next_page?,
    }
  end

end
