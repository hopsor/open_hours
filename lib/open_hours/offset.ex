defmodule OpenHours.Offset do
  @moduledoc """
  This module provides business time arithmetic operations.

  It allows shifting a DateTime forward or backward by a given amount of
  business time, skipping over non-working hours, weekends, holidays, and breaks.
  """

  alias OpenHours.{Schedule, TimeSlot}

  @duration_units [:hour, :minute]

  @type duration :: {integer(), :hour | :minute}

  @doc """
  Shifts a DateTime forward or backward by the given amount of business time.

  A positive amount shifts forward, a negative amount shifts backward.
  When the starting DateTime is outside business hours, it snaps to the next
  (forward) or previous (backward) business moment before applying the offset.

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
    raise ArgumentError, "unsupported unit #{inspect(unit)}, expected :hour or :minute"
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
end
