defmodule OpenHours.Duration do
  @moduledoc """
  This module contains functions to calculate business time duration.
  """

  alias OpenHours.{Schedule, TimeSlot}

  @doc """
  Calculates the business time elapsed between two DateTimes, in seconds.

  Only time that falls within business hours (as defined by the schedule) is counted.
  Non-working hours, weekends, holidays, and breaks are excluded.

  ## Examples

      iex> schedule = %OpenHours.Schedule{
      ...>   hours: %{
      ...>     mon: [{~T[09:00:00], ~T[17:00:00]}],
      ...>     tue: [{~T[09:00:00], ~T[17:00:00]}]
      ...>   },
      ...>   time_zone: "Etc/UTC"
      ...> }
      iex> starts_at = DateTime.from_naive!(~N[2026-03-16 10:00:00], "Etc/UTC")
      iex> ends_at = DateTime.from_naive!(~N[2026-03-16 15:00:00], "Etc/UTC")
      iex> OpenHours.Duration.between(schedule, starts_at, ends_at)
      18000

  """
  @spec between(Schedule.t(), DateTime.t(), DateTime.t()) :: non_neg_integer()
  def between(%Schedule{} = schedule, %DateTime{} = starts_at, %DateTime{} = ends_at) do
    schedule
    |> TimeSlot.between(starts_at, ends_at)
    |> Enum.map(&clamp_slot(&1, starts_at, ends_at))
    |> Enum.map(&slot_duration/1)
    |> Enum.sum()
  end

  defp clamp_slot(%TimeSlot{} = slot, starts_at, ends_at) do
    %TimeSlot{
      starts_at: max_datetime(slot.starts_at, starts_at),
      ends_at: min_datetime(slot.ends_at, ends_at)
    }
  end

  defp max_datetime(a, b) do
    if DateTime.compare(a, b) == :gt, do: a, else: b
  end

  defp min_datetime(a, b) do
    if DateTime.compare(a, b) == :lt, do: a, else: b
  end

  defp slot_duration(%TimeSlot{starts_at: starts_at, ends_at: ends_at}) do
    max(DateTime.diff(ends_at, starts_at, :second), 0)
  end
end
