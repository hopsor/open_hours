defmodule OpenHours.Interval do
  @moduledoc """
  This module contains functions for working with intervals of time.
  """

  @typedoc """
  A tuple of two Time structs representing the beginning and end of an interval.
  """
  @type t :: {Time.t(), Time.t()}

  @doc """
  Returns true if the interval contains the instant.
  """
  @spec within?(t(), DateTime.t() | Time.t()) :: boolean()
  def within?(interval, %DateTime{} = instant), do: within?(interval, DateTime.to_time(instant))

  def within?({starts_at, ends_at}, %Time{} = instant) do
    gte(instant, starts_at) && lte(instant, ends_at)
  end

  @doc """
  Calculates the difference between two intervals or two lists of intervals.

  It always returns a list of intervals.
  """
  @spec difference(list(t()) | t(), list(t()) | t()) :: list(t())
  def difference(a, b) when is_list(a) and is_list(b), do: process_difference_list(a, b)

  def difference({ax, ay} = a, {bx, by}) do
    cond do
      lte(ax, bx) and gte(bx, ay) -> [a]
      lte(ax, bx) and gte(by, ay) -> [{ax, bx}]
      lte(ax, bx) -> [{ax, bx}, {by, ay}]
      gte(ax, by) -> [a]
      lte(ay, by) -> []
      true -> [{by, ay}]
    end
    |> Enum.reject(fn {ax, ay} -> ax == ay end)
  end

  defp overlap?({ax, ay}, {bx, by}) do
    cond do
      gte(ay, bx) && lte(ay, by) -> true
      gte(ax, bx) && lte(ax, by) -> true
      gte(ay, by) && lte(ax, bx) -> true
      true -> false
    end
  end

  defp process_difference_list(a, []), do: a

  defp process_difference_list(a, [head | tail]) do
    {_, final_acc} =
      Enum.map_reduce(a, [], fn x, acc ->
        value_to_add = if overlap?(head, x), do: difference(x, head), else: [x]
        {value_to_add, acc ++ value_to_add}
      end)

    process_difference_list(final_acc, tail)
  end

  defp gte(%Time{} = a, %Time{} = b) do
    cmp = Time.compare(a, b)
    cmp == :gt || cmp == :eq
  end

  defp lte(%Time{} = a, %Time{} = b) do
    cmp = Time.compare(a, b)
    cmp == :lt || cmp == :eq
  end
end
