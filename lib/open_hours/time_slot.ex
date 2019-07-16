defmodule OpenHours.TimeSlot do
  @moduledoc """
  This module contains all functions to work with time slots.
  """

  import OpenHours.Common
  alias OpenHours.{TimeSlot, Schedule, Interval}

  @typedoc """
  Struct composed by a start datetime and an end datetime.
  """
  @type t :: %__MODULE__{starts_at: DateTime.t(), ends_at: DateTime.t()}

  @enforce_keys [:starts_at, :ends_at]
  defstruct [:starts_at, :ends_at]

  @doc """
  Calculates a list of time slots between two dates based on a Schedule. It follows the same rules
  as `OpenHours.Schedule.in_hours?/2`.
  """
  @spec between(OpenHours.Schedule.t(), DateTime.t(), DateTime.t()) :: [t()]
  def between(
        %Schedule{time_zone: schedule_tz} = schedule,
        %DateTime{time_zone: start_tz} = starts_at,
        %DateTime{} = ends_at
      )
      when schedule_tz != start_tz do
    {:ok, shifted_starts_at} = DateTime.shift_zone(starts_at, schedule_tz, Tzdata.TimeZoneDatabase)
    between(schedule, shifted_starts_at, ends_at)
  end

  def between(
        %Schedule{time_zone: schedule_tz} = schedule,
        %DateTime{} = starts_at,
        %DateTime{time_zone: end_tz} = ends_at
      )
      when schedule_tz != end_tz do
    {:ok, shifted_ends_at} = DateTime.shift_zone(ends_at, schedule_tz, Tzdata.TimeZoneDatabase)
    between(schedule, starts_at, shifted_ends_at)
  end

  def between(%Schedule{} = schedule, %DateTime{} = starts_at, %DateTime{} = ends_at) do
    starts_at
    |> DateTime.to_date()
    |> Date.range(DateTime.to_date(ends_at))
    |> Enum.reject(&Enum.member?(schedule.holidays, &1))
    |> Enum.flat_map(&time_slots_for(schedule, &1))
  end

  @doc """
  """
  @spec from(OpenHours.Schedule.t(), DateTime.t(), integer) :: [t()]
  def from(
        %Schedule{time_zone: schedule_tz} = schedule,
        %DateTime{time_zone: instant_tz} = instant,
        limit \\ 1
      )
      when schedule_tz != instant_tz do
    {:ok, shifted_instant} = DateTime.shift_zone(instant, schedule_tz, Tzdata.TimeZoneDatabase)
    from(schedule, shifted_instant, limit)
  end

  def from(%Schedule{} = schedule, %DateTime{} = instant, limit) do
    date_to_check = DateTime.to_date(instant)
    from_scan(schedule, instant, limit, [], date_to_check)
  end

  defp from_scan(_schedule, _instant, limit, acc, _date_to_check) when length(acc) == limit, do: acc

  defp from_scan(schedule, instant, limit, acc, date_to_check) do
    slots = time_slots_for(schedule, date_to_check)
    max = limit - length(acc)
    next_date_to_check = Date.add(date_to_check, 1)

    matching_slots =
      slots
      |> Enum.filter(fn %TimeSlot{ends_at: ends_at} -> ends_at >= instant end)
      |> Enum.take(max)

    from_scan(schedule, instant, limit, acc ++ matching_slots, next_date_to_check)
  end

  defp time_slots_for(
         %Schedule{} = schedule,
         %Date{} = day
       ) do
    schedule
    |> get_intervals_for(day)
    |> Enum.map(fn {interval_start, interval_end} ->
      %TimeSlot{
        starts_at:
          DateTime.from_naive!(
            build_date_time(day, interval_start),
            schedule.time_zone,
            Tzdata.TimeZoneDatabase
          ),
        ends_at:
          DateTime.from_naive!(
            build_date_time(day, interval_end),
            schedule.time_zone,
            Tzdata.TimeZoneDatabase
          )
      }
    end)
  end

  defp build_date_time(%Date{} = day, time) do
    with {:ok, date} <- NaiveDateTime.new(day, time), do: date
  end

  defp get_intervals_for(
         %Schedule{hours: hours, shifts: shifts, breaks: breaks},
         %Date{} = day
       ) do
    case Enum.find(shifts, fn {shift_date, _} -> shift_date == day end) do
      {_shift_date, intervals} ->
        intervals

      _ ->
        day_intervals = Map.get(hours, weekday(day), [])

        breaks
        |> Enum.find(breaks, fn {break_date, _} -> break_date == day end)
        |> case do
          {_, day_breaks} -> Interval.difference(day_intervals, day_breaks)
          _ -> day_intervals
        end
    end
  end
end
