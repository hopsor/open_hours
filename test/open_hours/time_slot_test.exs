defmodule OpenHours.TimeSlotTest do
  use ExUnit.Case

  alias OpenHours.{TimeSlot, Schedule}

  describe "between/3" do
    test "returns an empty list when the schedule is empty" do
      schedule = %Schedule{time_zone: "Europe/Madrid"}
      starts_at = build_dt(~N[2019-01-14 00:00:00])
      ends_at = build_dt(~N[2019-01-21 00:00:00])

      assert TimeSlot.between(schedule, starts_at, ends_at) == []
    end

    test "returns a list of proper timeslots when the schedule contains data" do
      schedule = %Schedule{
        hours: %{
          mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
          tue: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
          wed: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
          thu: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
        },
        shifts: [
          # Friday
          {~D[2019-01-18], [{~T[10:00:00], ~T[14:00:00]}]}
        ],
        breaks: [
          # Wednesday
          {~D[2019-01-16], [{~T[17:00:00], ~T[20:00:00]}]}
        ],
        holidays: [
          # Tuesday
          ~D[2019-01-15]
        ],
        time_zone: "Europe/Madrid"
      }

      starts_at = build_dt(~N[2019-01-14 00:00:00])
      ends_at = build_dt(~N[2019-01-20 00:00:00])

      expected_time_slots = [
        # Monday
        %TimeSlot{
          starts_at: build_dt(~N[2019-01-14 09:00:00]),
          ends_at: build_dt(~N[2019-01-14 14:00:00])
        },
        %TimeSlot{
          starts_at: build_dt(~N[2019-01-14 15:00:00]),
          ends_at: build_dt(~N[2019-01-14 20:00:00])
        },
        # Wednesday
        %TimeSlot{
          starts_at: build_dt(~N[2019-01-16 09:00:00]),
          ends_at: build_dt(~N[2019-01-16 14:00:00])
        },
        %TimeSlot{
          starts_at: build_dt(~N[2019-01-16 15:00:00]),
          ends_at: build_dt(~N[2019-01-16 17:00:00])
        },
        # Thursday
        %TimeSlot{
          starts_at: build_dt(~N[2019-01-17 09:00:00]),
          ends_at: build_dt(~N[2019-01-17 14:00:00])
        },
        %TimeSlot{
          starts_at: build_dt(~N[2019-01-17 15:00:00]),
          ends_at: build_dt(~N[2019-01-17 20:00:00])
        },
        # Friday
        %TimeSlot{
          starts_at: build_dt(~N[2019-01-18 10:00:00]),
          ends_at: build_dt(~N[2019-01-18 14:00:00])
        }
      ]

      assert TimeSlot.between(schedule, starts_at, ends_at) == expected_time_slots
    end
  end

  @schedule %Schedule{
    hours: %{
      mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      tue: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      wed: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      thu: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      fri: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
    },
    holidays: [~D[2019-01-15]],
    shifts: [{~D[2019-01-18], [{~T[10:00:00], ~T[14:00:00]}]}],
    breaks: [{~D[2019-01-16], [{~T[17:00:00], ~T[20:00:00]}]}],
    time_zone: "Europe/Madrid"
  }

  describe "next/3" do
    test "returns the containing slot when datetime is within business hours" do
      # Wednesday 2019-01-16 10:30 is within 09:00-14:00
      dt = build_dt(~N[2019-01-16 10:30:00])

      assert TimeSlot.next(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 09:00:00]),
                 ends_at: build_dt(~N[2019-01-16 14:00:00])
               }
             ]
    end

    test "returns the next slot when datetime is outside business hours" do
      # Wednesday 2019-01-16 14:30 is between the two slots
      dt = build_dt(~N[2019-01-16 14:30:00])

      assert TimeSlot.next(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               }
             ]
    end

    test "returns the next day's first slot when past all slots for the day" do
      # Wednesday 2019-01-16 21:00 is after all slots
      dt = build_dt(~N[2019-01-16 21:00:00])

      assert TimeSlot.next(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-17 09:00:00]),
                 ends_at: build_dt(~N[2019-01-17 14:00:00])
               }
             ]
    end

    test "skips holidays" do
      # Monday 2019-01-14 21:00 — next day (Tuesday) is a holiday, should skip to Wednesday
      dt = build_dt(~N[2019-01-14 21:00:00])

      assert TimeSlot.next(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 09:00:00]),
                 ends_at: build_dt(~N[2019-01-16 14:00:00])
               }
             ]
    end

    test "respects shifts" do
      # Friday 2019-01-18 has a shift: 10:00-14:00 instead of regular hours
      dt = build_dt(~N[2019-01-18 08:00:00])

      assert TimeSlot.next(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-18 10:00:00]),
                 ends_at: build_dt(~N[2019-01-18 14:00:00])
               }
             ]
    end

    test "respects breaks" do
      # Wednesday 2019-01-16 has a break 17:00-20:00, so second slot is 15:00-17:00
      dt = build_dt(~N[2019-01-16 16:00:00])

      assert TimeSlot.next(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               }
             ]
    end

    test "returns multiple slots with limit option" do
      dt = build_dt(~N[2019-01-16 10:30:00])

      result = TimeSlot.next(@schedule, dt, limit: 3)

      assert result == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 09:00:00]),
                 ends_at: build_dt(~N[2019-01-16 14:00:00])
               },
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               },
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-17 09:00:00]),
                 ends_at: build_dt(~N[2019-01-17 14:00:00])
               }
             ]
    end

    test "excludes containing slot with inclusive: false" do
      # Wednesday 2019-01-16 10:30 is within 09:00-14:00, but we want the next one
      dt = build_dt(~N[2019-01-16 10:30:00])

      assert TimeSlot.next(@schedule, dt, inclusive: false) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               }
             ]
    end

    test "inclusive: false has no effect when outside business hours" do
      dt = build_dt(~N[2019-01-16 14:30:00])

      assert TimeSlot.next(@schedule, dt, inclusive: false) ==
               TimeSlot.next(@schedule, dt)
    end

    test "skips weekends" do
      # Friday 2019-01-18 after the shift ends — no Sat/Sun hours, should go to Monday
      dt = build_dt(~N[2019-01-18 15:00:00])

      assert TimeSlot.next(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-21 09:00:00]),
                 ends_at: build_dt(~N[2019-01-21 14:00:00])
               }
             ]
    end

    test "returns empty list for an empty schedule" do
      empty = %Schedule{time_zone: "Europe/Madrid"}
      dt = build_dt(~N[2019-01-16 10:00:00])

      assert TimeSlot.next(empty, dt) == []
    end
  end

  describe "previous/3" do
    test "returns the containing slot when datetime is within business hours" do
      dt = build_dt(~N[2019-01-16 10:30:00])

      assert TimeSlot.previous(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 09:00:00]),
                 ends_at: build_dt(~N[2019-01-16 14:00:00])
               }
             ]
    end

    test "returns the previous slot when datetime is outside business hours" do
      # Wednesday 2019-01-16 14:30 is between slots
      dt = build_dt(~N[2019-01-16 14:30:00])

      assert TimeSlot.previous(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 09:00:00]),
                 ends_at: build_dt(~N[2019-01-16 14:00:00])
               }
             ]
    end

    test "returns the previous day's last slot when before all slots for the day" do
      # Wednesday 2019-01-16 07:00 — should return Monday's last slot (Tue is holiday)
      dt = build_dt(~N[2019-01-16 07:00:00])

      assert TimeSlot.previous(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-14 15:00:00]),
                 ends_at: build_dt(~N[2019-01-14 20:00:00])
               }
             ]
    end

    test "skips holidays" do
      # Wednesday 2019-01-16 07:00 — Tuesday is a holiday, should return Monday's last slot
      dt = build_dt(~N[2019-01-16 07:00:00])

      assert TimeSlot.previous(@schedule, dt) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-14 15:00:00]),
                 ends_at: build_dt(~N[2019-01-14 20:00:00])
               }
             ]
    end

    test "returns multiple slots with limit option" do
      dt = build_dt(~N[2019-01-17 10:30:00])

      result = TimeSlot.previous(@schedule, dt, limit: 3)

      assert result == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-17 09:00:00]),
                 ends_at: build_dt(~N[2019-01-17 14:00:00])
               },
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               },
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 09:00:00]),
                 ends_at: build_dt(~N[2019-01-16 14:00:00])
               }
             ]
    end

    test "excludes containing slot with inclusive: false" do
      dt = build_dt(~N[2019-01-16 10:30:00])

      assert TimeSlot.previous(@schedule, dt, inclusive: false) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-14 15:00:00]),
                 ends_at: build_dt(~N[2019-01-14 20:00:00])
               }
             ]
    end

    test "inclusive: false has no effect when outside business hours" do
      dt = build_dt(~N[2019-01-16 14:30:00])

      assert TimeSlot.previous(@schedule, dt, inclusive: false) ==
               TimeSlot.previous(@schedule, dt)
    end

    test "returns empty list for an empty schedule" do
      empty = %Schedule{time_zone: "Europe/Madrid"}
      dt = build_dt(~N[2019-01-16 10:00:00])

      assert TimeSlot.previous(empty, dt) == []
    end
  end

  defp build_dt(naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Europe/Madrid", Tzdata.TimeZoneDatabase)
  end
end
