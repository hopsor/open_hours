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

  defp build_dt(naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Europe/Madrid", Tzdata.TimeZoneDatabase)
  end
end
