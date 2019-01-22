defmodule OpenHours.ScheduleTest do
  use ExUnit.Case

  alias OpenHours.Schedule

  describe "in_hours/2" do
    test "returns true when the moment is within schedule" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        time_zone: "Europe/Madrid"
      }

      at = DateTime.from_naive!(~N[2019-01-14 12:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

      assert Schedule.in_hours?(schedule, at) == true
    end

    test "returns false when the moment isn't within schedule" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        time_zone: "Europe/Madrid"
      }

      at = DateTime.from_naive!(~N[2019-01-14 14:30:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

      assert Schedule.in_hours?(schedule, at) == false
    end

    test "returns false when the schedule is empty" do
      schedule = %Schedule{time_zone: "Europe/Madrid"}
      {:ok, at} = DateTime.now("Europe/Madrid", Tzdata.TimeZoneDatabase)
      assert Schedule.in_hours?(schedule, at) == false
    end

    test "returns false when there's a holiday matching" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        holidays: [~D[2019-01-14]],
        time_zone: "Europe/Madrid"
      }

      at = DateTime.from_naive!(~N[2019-01-14 14:30:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

      assert Schedule.in_hours?(schedule, at) == false
    end

    test "returns false when the moment is between a break" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        breaks: [
          {~D[2019-01-14], [{~T[12:00:00], ~T[14:00:00]}]}
        ],
        time_zone: "Europe/Madrid"
      }

      at = DateTime.from_naive!(~N[2019-01-14 13:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

      assert Schedule.in_hours?(schedule, at) == false
    end

    test "returns true when the moment isn't between a break" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        breaks: [
          {~D[2019-01-14], [{~T[12:00:00], ~T[14:00:00]}]}
        ],
        time_zone: "Europe/Madrid"
      }

      at = DateTime.from_naive!(~N[2019-01-14 10:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

      assert Schedule.in_hours?(schedule, at) == true
    end

    test "returns false when the moment is in a shift day but not between its intervals" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        shifts: [
          {~D[2019-01-14], [{~T[10:00:00], ~T[15:00:00]}]}
        ],
        time_zone: "Europe/Madrid"
      }

      at = DateTime.from_naive!(~N[2019-01-14 16:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

      assert Schedule.in_hours?(schedule, at) == false
    end

    test "returns true when the moment is in a shift day between its intervals" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        shifts: [
          {~D[2019-01-14], [{~T[10:00:00], ~T[15:00:00]}]}
        ],
        time_zone: "Europe/Madrid"
      }

      at = DateTime.from_naive!(~N[2019-01-14 14:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)

      assert Schedule.in_hours?(schedule, at) == true
    end
  end
end
