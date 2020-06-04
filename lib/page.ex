defmodule Pager.Page do
  @moduledoc """
  Models a page of results. Contains:
  * The results themselves
  * The total count of results in the resultset
  * Pagination information (whether there's a previous/next page, cursors)
  """
  @enforce_keys ~w(page_info total_count edges)a
  defstruct @enforce_keys

  alias Pager.{Page, PageInfo}

  @type t(edge) :: %Page{
    page_info: PageInfo.t,
    total_count: non_neg_integer,
    edges: [edge],
  }
  @type t() :: t(term)

  @doc "Create a new page from its data, count, cursor function and page options"
  @spec new(edges :: [t], total_count :: non_neg_integer, Pager.t, page_opts :: map) :: t
  def new(edges, total_count, %Pager{}=pager, page_opts)
  when is_list(edges) and is_integer(total_count) and total_count >= 0 do
    new2(edges, total_count, pager, page_opts)
  end

  # the real new
  defp new2(edges, count, pager, opts)

  defp new2([], count, _, _), do: page(PageInfo.new(nil, nil, false, false), count, [])

  defp new2([ e | es ] = edges, count, pager, %{after: a, limit: limit}) do
    if pager.cursor_generator.(e) == a,
      do: new_after(true, es, count, limit, pager), # underscan matches
      else: new_after(nil, Enum.take(edges, limit+1), count, limit, pager) # uhoh
  end

  defp new2(edges, count, pager, %{before: b, limit: limit}) do
    if pager.cursor_generator.(List.last(edges)) == b,
      do: new_before(true, :lists.droplast(edges), count, limit, pager), # overscan matches
      else: new_before(nil, Enum.slice(edges, -(limit-1)..-1), count, limit, pager) # uhoh
  end

  defp new2(edges, count, pager, %{limit: limit}), do: new_after(false, edges, count, limit, pager)

  defp new_after(has_prev?, edges, count, limit, pager) do
    if Enum.count(edges) > limit,
      do: page(has_prev?, true, Enum.take(edges, limit), count, pager),
      else: page(has_prev?, false, edges, count, pager)
  end

  defp new_before(has_next?, edges, count, limit, pager) do
    if Enum.count(edges) > limit,
      do: page(true, has_next?, Enum.take(edges, limit), count, pager),
      else: page(false, has_next?, edges, count, pager)
  end

  # directly construct a page from constituents
  defp page(info, count, edges), do: %Page{ page_info: info, total_count: count, edges: edges }

  # construct a pageinfo and then a page
  defp page(has_prev?, has_next?, edges, count, pager)
  defp page(_, _, [], count, _), do: new2([], count, [], [])
  defp page(has_prev?, has_next?, edges, count, pager) do
    first = pager.cursor_fn.(List.first(edges))
    last = pager.cursor_fn.(List.last(edges))
    page(PageInfo.new(first, last, has_prev?, has_next?), count, edges)
  end

end
