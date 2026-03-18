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

    test "excludes containing slot with include_overlap: false" do
      # Wednesday 2019-01-16 10:30 is within 09:00-14:00, but we want the next one
      dt = build_dt(~N[2019-01-16 10:30:00])

      assert TimeSlot.next(@schedule, dt, include_overlap: false) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               }
             ]
    end

    test "include_overlap: false has no effect when outside business hours" do
      dt = build_dt(~N[2019-01-16 14:30:00])

      assert TimeSlot.next(@schedule, dt, include_overlap: false) ==
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

    test "excludes containing slot with include_overlap: false" do
      dt = build_dt(~N[2019-01-16 10:30:00])

      assert TimeSlot.previous(@schedule, dt, include_overlap: false) == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-14 15:00:00]),
                 ends_at: build_dt(~N[2019-01-14 20:00:00])
               }
             ]
    end

    test "include_overlap: false has no effect when outside business hours" do
      dt = build_dt(~N[2019-01-16 14:30:00])

      assert TimeSlot.previous(@schedule, dt, include_overlap: false) ==
               TimeSlot.previous(@schedule, dt)
    end

    test "returns empty list for an empty schedule" do
      empty = %Schedule{time_zone: "Europe/Madrid"}
      dt = build_dt(~N[2019-01-16 10:00:00])

      assert TimeSlot.previous(empty, dt) == []
    end
  end

  describe "stream_next/3" do
    test "returns a lazy stream of time slots" do
      dt = build_dt(~N[2019-01-16 00:00:00])
      slots = @schedule |> TimeSlot.stream_next(dt) |> Enum.take(3)

      assert slots == [
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

    test "includes overlapping slot by default" do
      # Wed 10:30 is within 09:00-14:00, should include that slot
      dt = build_dt(~N[2019-01-16 10:30:00])
      slots = @schedule |> TimeSlot.stream_next(dt) |> Enum.take(1)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 09:00:00]),
                 ends_at: build_dt(~N[2019-01-16 14:00:00])
               }
             ]
    end

    test "excludes overlapping slot with include_overlap: false" do
      # Wed 10:30 is within 09:00-14:00, skip it
      dt = build_dt(~N[2019-01-16 10:30:00])
      slots = @schedule |> TimeSlot.stream_next(dt, include_overlap: false) |> Enum.take(1)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               }
             ]
    end

    test "skips holidays" do
      # Starting from Monday, Tuesday is a holiday
      dt = build_dt(~N[2019-01-14 00:00:00])
      slots = @schedule |> TimeSlot.stream_next(dt) |> Enum.take(3)

      assert [first, second, _] = slots
      assert DateTime.to_date(first.starts_at) == ~D[2019-01-14]
      assert DateTime.to_date(second.starts_at) == ~D[2019-01-14]
      # Third slot is Wednesday (skips Tuesday holiday)
    end

    test "skips weekends" do
      # Starting from Friday (shift day), next slots are Monday
      dt = build_dt(~N[2019-01-18 00:00:00])
      slots = @schedule |> TimeSlot.stream_next(dt) |> Enum.take(2)

      assert [friday, monday] = slots
      assert DateTime.to_date(friday.starts_at) == ~D[2019-01-18]
      assert DateTime.to_date(monday.starts_at) == ~D[2019-01-21]
    end

    test "respects shifts" do
      # Friday 2019-01-18 has shift 10:00-14:00 (single slot instead of two)
      dt = build_dt(~N[2019-01-18 00:00:00])
      slots = @schedule |> TimeSlot.stream_next(dt) |> Enum.take(1)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-18 10:00:00]),
                 ends_at: build_dt(~N[2019-01-18 14:00:00])
               }
             ]
    end

    test "respects breaks" do
      # Wednesday 2019-01-16 has break 17:00-20:00
      dt = build_dt(~N[2019-01-16 00:00:00])
      slots = @schedule |> TimeSlot.stream_next(dt) |> Enum.take(2)

      assert [_, second] = slots
      assert second.ends_at == build_dt(~N[2019-01-16 17:00:00])
    end

    test "returns empty stream for empty schedule" do
      empty = %Schedule{time_zone: "Europe/Madrid"}
      dt = build_dt(~N[2019-01-16 10:00:00])
      slots = empty |> TimeSlot.stream_next(dt) |> Enum.take(1)

      assert slots == []
    end

    test "does not loop infinitely when hours are empty and shifts are in the past" do
      schedule = %Schedule{
        hours: %{},
        shifts: [{~D[2019-01-15], [{~T[10:00:00], ~T[15:00:00]}]}],
        time_zone: "Europe/Madrid"
      }

      dt = build_dt(~N[2019-01-16 10:00:00])
      slots = schedule |> TimeSlot.stream_next(dt) |> Enum.take(1)

      assert slots == []
    end

    test "returns shift slots when hours are empty and shift is ahead" do
      schedule = %Schedule{
        hours: %{},
        shifts: [{~D[2019-01-18], [{~T[10:00:00], ~T[15:00:00]}]}],
        time_zone: "Europe/Madrid"
      }

      dt = build_dt(~N[2019-01-16 10:00:00])
      slots = schedule |> TimeSlot.stream_next(dt) |> Enum.take(1)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-18 10:00:00]),
                 ends_at: build_dt(~N[2019-01-18 15:00:00])
               }
             ]
    end
  end

  describe "stream_previous/3" do
    test "returns a lazy stream of time slots in reverse" do
      dt = build_dt(~N[2019-01-17 23:00:00])
      slots = @schedule |> TimeSlot.stream_previous(dt) |> Enum.take(3)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-17 15:00:00]),
                 ends_at: build_dt(~N[2019-01-17 20:00:00])
               },
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-17 09:00:00]),
                 ends_at: build_dt(~N[2019-01-17 14:00:00])
               },
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               }
             ]
    end

    test "includes overlapping slot by default" do
      # Thu 10:30 is within 09:00-14:00, should include that slot
      dt = build_dt(~N[2019-01-17 10:30:00])
      slots = @schedule |> TimeSlot.stream_previous(dt) |> Enum.take(1)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-17 09:00:00]),
                 ends_at: build_dt(~N[2019-01-17 14:00:00])
               }
             ]
    end

    test "excludes overlapping slot with include_overlap: false" do
      # Thu 10:30 is within 09:00-14:00, skip it
      dt = build_dt(~N[2019-01-17 10:30:00])
      slots = @schedule |> TimeSlot.stream_previous(dt, include_overlap: false) |> Enum.take(1)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-16 15:00:00]),
                 ends_at: build_dt(~N[2019-01-16 17:00:00])
               }
             ]
    end

    test "skips holidays" do
      # Starting from Wednesday backward, Tuesday is a holiday
      dt = build_dt(~N[2019-01-16 23:00:00])
      slots = @schedule |> TimeSlot.stream_previous(dt) |> Enum.take(4)

      dates = Enum.map(slots, &DateTime.to_date(&1.starts_at))
      # Should go Wed, Wed, then skip Tue to Mon, Mon
      assert dates == [~D[2019-01-16], ~D[2019-01-16], ~D[2019-01-14], ~D[2019-01-14]]
    end

    test "skips weekends" do
      # Starting from Monday backward, Mon has 2 slots, then skip Sat/Sun to Friday
      dt = build_dt(~N[2019-01-21 23:00:00])
      slots = @schedule |> TimeSlot.stream_previous(dt) |> Enum.take(3)

      dates = Enum.map(slots, &DateTime.to_date(&1.starts_at))
      assert dates == [~D[2019-01-21], ~D[2019-01-21], ~D[2019-01-18]]
    end

    test "returns empty stream for empty schedule" do
      empty = %Schedule{time_zone: "Europe/Madrid"}
      dt = build_dt(~N[2019-01-16 10:00:00])
      slots = empty |> TimeSlot.stream_previous(dt) |> Enum.take(1)

      assert slots == []
    end

    test "does not loop infinitely when hours are empty and shifts are in the future" do
      schedule = %Schedule{
        hours: %{},
        shifts: [{~D[2019-01-18], [{~T[10:00:00], ~T[15:00:00]}]}],
        time_zone: "Europe/Madrid"
      }

      dt = build_dt(~N[2019-01-16 10:00:00])
      slots = schedule |> TimeSlot.stream_previous(dt) |> Enum.take(1)

      assert slots == []
    end

    test "returns shift slots when hours are empty and shift is behind" do
      schedule = %Schedule{
        hours: %{},
        shifts: [{~D[2019-01-15], [{~T[10:00:00], ~T[15:00:00]}]}],
        time_zone: "Europe/Madrid"
      }

      dt = build_dt(~N[2019-01-16 10:00:00])
      slots = schedule |> TimeSlot.stream_previous(dt) |> Enum.take(1)

      assert slots == [
               %TimeSlot{
                 starts_at: build_dt(~N[2019-01-15 10:00:00]),
                 ends_at: build_dt(~N[2019-01-15 15:00:00])
               }
             ]
    end
  end

  defp build_dt(naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Europe/Madrid", Tzdata.TimeZoneDatabase)
  end
end
