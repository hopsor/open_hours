defmodule OpenHours.Offset do
  @moduledoc """
  This module provides business time arithmetic operations.

  It allows shifting a DateTime forward or backward by a given amount of
  business time, skipping over non-working hours, weekends, holidays, and breaks.
  """

  alias OpenHours.{Schedule, TimeSlot}

  @duration_units [:hour, :minute, :day]

  @type duration :: {integer(), :hour | :minute | :day}

  @doc """
  Shifts a DateTime forward or backward by the given amount of business time.

  A positive amount shifts forward, a negative amount shifts backward.
  Supports `:hour`, `:minute`, and `:day` units.

  ## Hour and minute shifts

  For `:hour` and `:minute` units, the shift consumes the exact amount of
  business time, walking through consecutive time slots and skipping
  non-working periods. When the starting DateTime is outside business hours,
  it snaps to the next (forward) or previous (backward) business moment
  before applying the offset.

  ## Day shifts

  For the `:day` unit, the shift moves to the Nth business day forward or
  backward, preserving the time of day when possible. A "business day" is
  any day that has at least one time slot in the schedule (not a holiday,
  and has configured hours or a shift override).

  The current day is never counted — `{1, :day}` always moves to a
  different date.

  ### Time preservation and snapping

  The algorithm tries to keep the original time of day on the target date.
  When the time falls within business hours on the target day, it is
  preserved exactly. When it does not, the result is the nearest business
  moment in the direction of the shift — which may be on a different day
  than the target:

    * **Forward**: finds the next business moment after the target
      date + time. If the time falls in a gap between slots on the
      target day, this is the start of the next slot on that day. If
      the time is past all slots on the target day, this is the start
      of business on the next business day.
    * **Backward**: finds the previous business moment before the
      target date + time. If the time falls in a gap, this is the end
      of the preceding slot. If the time is before all slots, this is
      the end of business on the previous business day.

  This matters when the target day has different hours than the origin day
  (e.g. a shift override with shorter hours, or a day with breaks that
  create gaps).

  ### Examples

  Given a schedule with Mon–Fri 09:00–14:00 and 15:00–20:00, and
  Friday overridden with a shift of 10:00–14:00:

      # Time preserved: 10:00 exists in both days' hours
      shift(schedule, ~N[2019-01-16 10:00:00], {1, :day})
      #=> Thursday 10:00

      # 15:00 is past Friday's shift (10:00–14:00), no later slot on
      # Friday, so it flows forward to the next business day
      shift(schedule, ~N[2019-01-17 15:00:00], {1, :day})
      #=> Monday 09:00

      # 14:30 falls in the gap between 09–14 and 15–20, snaps to
      # the start of the next slot on the same day
      shift(schedule, ~N[2019-01-14 14:30:00], {1, :day})
      #=> Wednesday 15:00

  ## Examples

      iex> schedule = %OpenHours.Schedule{
      ...>   hours: %{
      ...>     mon: [{~T[09:00:00], ~T[17:00:00]}],
      ...>     tue: [{~T[09:00:00], ~T[17:00:00]}]
      ...>   },
      ...>   time_zone: "Europe/Madrid"
      ...> }
      iex> dt = DateTime.from_naive!(~N[2019-01-14 10:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
      iex> OpenHours.Offset.shift(schedule, dt, {2, :hour})
      DateTime.from_naive!(~N[2019-01-14 12:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

  """
  @spec shift(Schedule.t(), DateTime.t(), duration()) :: DateTime.t()
  def shift(
        %Schedule{time_zone: schedule_tz} = schedule,
        %DateTime{time_zone: dt_tz} = dt,
        duration
      )
      when schedule_tz != dt_tz do
    {:ok, shifted} = DateTime.shift_zone(dt, schedule_tz, Tzdata.TimeZoneDatabase)
    shift(schedule, shifted, duration)
  end

  def shift(%Schedule{} = schedule, %DateTime{} = dt, {amount, :day})
      when amount > 0 do
    shift_days_forward(schedule, dt, amount)
  end

  def shift(%Schedule{} = schedule, %DateTime{} = dt, {amount, :day})
      when amount < 0 do
    shift_days_backward(schedule, dt, abs(amount))
  end

  def shift(%Schedule{} = schedule, %DateTime{} = dt, {amount, unit})
      when amount > 0 and unit in @duration_units do
    shift_forward(schedule, dt, to_seconds(amount, unit))
  end

  def shift(%Schedule{} = schedule, %DateTime{} = dt, {amount, unit})
      when amount < 0 and unit in @duration_units do
    shift_backward(schedule, dt, to_seconds(abs(amount), unit))
  end

  def shift(%Schedule{}, %DateTime{}, {0, unit}) when unit in @duration_units do
    raise ArgumentError, "amount must be a non-zero integer, got: 0"
  end

  def shift(%Schedule{}, %DateTime{}, {_amount, unit}) when unit not in @duration_units do
    raise ArgumentError, "unsupported unit #{inspect(unit)}, expected :hour, :minute, or :day"
  end

  defp shift_forward(schedule, dt, remaining_seconds) do
    case TimeSlot.next(schedule, dt, limit: 1) do
      [] -> raise ArgumentError, "no business hours available in the schedule"
      [slot] -> shift_forward_slot(slot, schedule, dt, remaining_seconds)
    end
  end

  defp shift_forward_slot(slot, schedule, dt, remaining_seconds) do
    position = max_dt(dt, slot.starts_at)
    available = DateTime.diff(slot.ends_at, position)

    if available >= remaining_seconds do
      DateTime.add(position, remaining_seconds, :second, Tzdata.TimeZoneDatabase)
    else
      shift_forward(schedule, slot.ends_at, remaining_seconds - available)
    end
  end

  defp shift_backward(schedule, dt, remaining_seconds) do
    case TimeSlot.previous(schedule, dt, limit: 1) do
      [] -> raise ArgumentError, "no business hours available in the schedule"
      [slot] -> shift_backward_slot(slot, schedule, dt, remaining_seconds)
    end
  end

  defp shift_backward_slot(slot, schedule, dt, remaining_seconds) do
    position = min_dt(dt, slot.ends_at)
    available = DateTime.diff(position, slot.starts_at)

    if available >= remaining_seconds do
      DateTime.add(position, -remaining_seconds, :second, Tzdata.TimeZoneDatabase)
    else
      shift_backward(schedule, slot.starts_at, remaining_seconds - available)
    end
  end

  defp to_seconds(amount, :hour), do: amount * 3600
  defp to_seconds(amount, :minute), do: amount * 60

  defp max_dt(a, b) do
    if DateTime.compare(a, b) == :gt, do: a, else: b
  end

  defp min_dt(a, b) do
    if DateTime.compare(a, b) == :lt, do: a, else: b
  end

  defp shift_days_forward(schedule, dt, count) do
    time = DateTime.to_time(dt)

    target_date =
      schedule
      |> TimeSlot.stream_next(dt, include_overlap: false)
      |> Stream.map(&DateTime.to_date(&1.starts_at))
      |> Stream.dedup()
      |> Stream.drop_while(&(Date.compare(&1, DateTime.to_date(dt)) == :eq))
      |> Enum.at(count - 1)

    snap_to_business_time(schedule, target_date, time, :forward)
  end

  defp shift_days_backward(schedule, dt, count) do
    time = DateTime.to_time(dt)

    target_date =
      schedule
      |> TimeSlot.stream_previous(dt, include_overlap: false)
      |> Stream.map(&DateTime.to_date(&1.starts_at))
      |> Stream.dedup()
      |> Stream.drop_while(&(Date.compare(&1, DateTime.to_date(dt)) == :eq))
      |> Enum.at(count - 1)

    snap_to_business_time(schedule, target_date, time, :backward)
  end

  defp snap_to_business_time(schedule, date, time, direction) do
    dt = DateTime.new!(date, time, schedule.time_zone, Tzdata.TimeZoneDatabase)

    if Schedule.in_hours?(schedule, dt) do
      dt
    else
      find_nearest_business_moment(schedule, dt, direction)
    end
  end

  defp find_nearest_business_moment(schedule, dt, :forward) do
    case TimeSlot.next(schedule, dt, limit: 1) do
      [slot] -> max_dt(dt, slot.starts_at)
      [] -> raise ArgumentError, "no business hours available in the schedule"
    end
  end

  defp find_nearest_business_moment(schedule, dt, :backward) do
    case TimeSlot.previous(schedule, dt, limit: 1) do
      [slot] -> min_dt(dt, slot.ends_at)
      [] -> raise ArgumentError, "no business hours available in the schedule"
    end
  end
end
