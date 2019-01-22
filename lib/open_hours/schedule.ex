defmodule OpenHours.Schedule do
  @moduledoc """
  This module contains functions to work with schedules.

  There are five settings to configure a schedule.

  - `hours`: Map containing all the open hours intervals for a regular week.
  - `holidays`: Dates in which the business is closed.
  - `shifts`: Special dates where the business has a different hour schedule.
  - `breaks`: Special dates where the business has interruption intervals.
  - `time_zone`: Time zone of the schedule.

  All the `%Time{}` values used for the schedule must be in local time.
  """

  import OpenHours.Common
  alias OpenHours.{Schedule, Interval}

  @typedoc """
  A struct representing the regular weekly schedule. Each key corresponds with the three first
  characters of a week day. The values of each key are composed by lists of intervals.
  """
  @type hour_schedule :: %{
          optional(:mon) => list(Interval.t()),
          optional(:tue) => list(Interval.t()),
          optional(:wed) => list(Interval.t()),
          optional(:thu) => list(Interval.t()),
          optional(:fri) => list(Interval.t()),
          optional(:sat) => list(Interval.t()),
          optional(:sun) => list(Interval.t())
        }

  @typedoc """
  A list of Date structs representing the days the business is closed
  """
  @type holidays :: list(Date.t())

  @typedoc """
  A string containing a valid IANA time zone
  """
  @type time_zone :: String.t()

  @typedoc """
  A tuple formed by a date and a list of intervals
  """
  @type shift :: {Date.t(), list(Interval.t())}

  @typedoc """
  A list of shifts
  """
  @type shifts :: list(shift)

  @typedoc """
  A tuple formed by a date and a list of intervals
  """
  @type break :: {Date.t(), list(Interval.t())}

  @typedoc """
  A list of breaks
  """
  @type breaks :: list(break)

  @typedoc """
  A struct containing all data of a schedule
  """
  @type t :: %__MODULE__{
          hours: hour_schedule,
          shifts: shifts,
          breaks: breaks,
          holidays: holidays,
          time_zone: time_zone
        }

  @enforce_keys [:time_zone]
  defstruct hours: %{}, shifts: [], breaks: [], holidays: [], time_zone: nil

  @doc """
  It returns `true` if the supplied `%DateTime{}` is within the business hours. The result is
  calculated based on all the settings of the schedule (hours, shifts, breaks and holidays).

  The rules applied to establish if the date passed is in business hours is the following.

  Shifts act as exceptions to the hours configured for a particular date; that is, if a date is
  configured with both hours-based intervals and shifts, the shifts are in force and the intervals
  are disregarded.

  Periods occurring on holidays are disregarded.

  Periods that overlaps with a break are treated as inactive. In case a date overlaps with a shift
  and a break the shift will have priority. Priority works as follows:

  Holidays > Shifts > Breaks > Hours
  """
  @spec in_hours?(OpenHours.Schedule.t(), DateTime.t()) :: boolean()
  def in_hours?(%Schedule{time_zone: schedule_tz} = schedule, %DateTime{time_zone: date_tz} = at)
      when schedule_tz != date_tz do
    {:ok, shifted_at} = DateTime.shift_zone(at, schedule_tz, Tzdata.TimeZoneDatabase)
    in_hours?(schedule, shifted_at)
  end

  def in_hours?(%Schedule{} = schedule, %DateTime{} = at) do
    with date <- DateTime.to_date(at),
         false <- in_holidays?(schedule, date),
         shifts <- shifts_for(schedule, date) do
      case shifts do
        nil -> is_within_business_hours?(schedule, at) && !is_within_breaks?(schedule, at)
        _ -> Enum.any?(shifts, &Interval.within?(&1, at))
      end
    else
      _ -> false
    end
  end

  defp shifts_for(%Schedule{shifts: shifts}, %Date{} = at) do
    case Enum.find(shifts, fn {shift_date, _} -> shift_date == at end) do
      {_, shift_intervals} -> shift_intervals
      _ -> nil
    end
  end

  defp is_within_business_hours?(%Schedule{} = schedule, %DateTime{} = at) do
    schedule.hours
    |> Map.get(weekday(at), [])
    |> Enum.any?(&Interval.within?(&1, at))
  end

  defp is_within_breaks?(%Schedule{breaks: breaks}, %DateTime{} = at) do
    date = DateTime.to_date(at)

    case Enum.find(breaks, fn {break_date, _intervals} -> break_date == date end) do
      {_break_date, intervals} -> Enum.any?(intervals, &Interval.within?(&1, at))
      _ -> false
    end
  end

  defp in_holidays?(%Schedule{holidays: holidays}, %Date{} = at), do: Enum.member?(holidays, at)
end
