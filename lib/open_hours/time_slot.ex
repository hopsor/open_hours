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
    |> Enum.flat_map(&time_slots_for_day(schedule, &1))
  end

  @doc """
  Returns the next time slots from the given DateTime, looking forward in the schedule.

  ## Options

    * `:limit` - number of slots to return (default: `1`)
    * `:include_overlap` - if `true`, includes the slot containing the given DateTime
      (default: `true`)

  Returns a list of `%TimeSlot{}` structs ordered chronologically.
  """
  @spec next(Schedule.t(), DateTime.t(), keyword()) :: [t()]
  def next(schedule, at, opts \\ [])

  def next(%Schedule{time_zone: schedule_tz} = schedule, %DateTime{time_zone: dt_tz} = at, opts)
      when schedule_tz != dt_tz do
    {:ok, shifted} = DateTime.shift_zone(at, schedule_tz, Tzdata.TimeZoneDatabase)
    next(schedule, shifted, opts)
  end

  def next(%Schedule{} = schedule, %DateTime{} = _at, _opts)
      when schedule.hours == %{} and schedule.shifts == [] do
    []
  end

  def next(%Schedule{} = schedule, %DateTime{} = at, opts) do
    limit = Keyword.get(opts, :limit, 1)
    include_overlap = Keyword.get(opts, :include_overlap, true)

    schedule
    |> stream_forward(DateTime.to_date(at))
    |> Stream.filter(fn slot ->
      if include_overlap do
        DateTime.compare(slot.ends_at, at) == :gt
      else
        DateTime.compare(slot.starts_at, at) == :gt
      end
    end)
    |> Enum.take(limit)
  end

  @doc """
  Returns the previous time slots from the given DateTime, looking backward in the schedule.

  ## Options

    * `:limit` - number of slots to return (default: `1`)
    * `:include_overlap` - if `true`, includes the slot containing the given DateTime
      (default: `true`)

  Returns a list of `%TimeSlot{}` structs ordered from most recent to least recent.
  """
  @spec previous(Schedule.t(), DateTime.t(), keyword()) :: [t()]
  def previous(schedule, at, opts \\ [])

  def previous(%Schedule{time_zone: schedule_tz} = schedule, %DateTime{time_zone: dt_tz} = at, opts)
      when schedule_tz != dt_tz do
    {:ok, shifted} = DateTime.shift_zone(at, schedule_tz, Tzdata.TimeZoneDatabase)
    previous(schedule, shifted, opts)
  end

  def previous(%Schedule{} = schedule, %DateTime{} = _at, _opts)
      when schedule.hours == %{} and schedule.shifts == [] do
    []
  end

  def previous(%Schedule{} = schedule, %DateTime{} = at, opts) do
    limit = Keyword.get(opts, :limit, 1)
    include_overlap = Keyword.get(opts, :include_overlap, true)

    schedule
    |> stream_backward(DateTime.to_date(at))
    |> Stream.filter(fn slot ->
      if include_overlap do
        DateTime.compare(slot.starts_at, at) == :lt
      else
        DateTime.compare(slot.ends_at, at) == :lt
      end
    end)
    |> Enum.take(limit)
  end

  defp stream_forward(%Schedule{} = schedule, %Date{} = from) do
    from
    |> Stream.iterate(&Date.add(&1, 1))
    |> Stream.reject(&Enum.member?(schedule.holidays, &1))
    |> Stream.flat_map(&time_slots_for_day(schedule, &1))
  end

  defp stream_backward(%Schedule{} = schedule, %Date{} = from) do
    from
    |> Stream.iterate(&Date.add(&1, -1))
    |> Stream.reject(&Enum.member?(schedule.holidays, &1))
    |> Stream.flat_map(&(schedule |> time_slots_for_day(&1) |> Enum.reverse()))
  end

  defp time_slots_for_day(%Schedule{} = schedule, %Date{} = day) do
    schedule
    |> get_intervals_for(day)
    |> Enum.map(fn {interval_start, interval_end} ->
      %TimeSlot{
        starts_at: DateTime.new!(day, interval_start, schedule.time_zone, Tzdata.TimeZoneDatabase),
        ends_at: DateTime.new!(day, interval_end, schedule.time_zone, Tzdata.TimeZoneDatabase)
      }
    end)
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
