defmodule OpenHours.DurationTest do
  use ExUnit.Case

  alias OpenHours.{Duration, Schedule}

  doctest OpenHours.Duration

  @schedule %Schedule{
    hours: %{
      mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      tue: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      wed: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      thu: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
      fri: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
    },
    time_zone: "Europe/Madrid"
  }

  describe "between/3" do
    test "returns 0 for an empty schedule" do
      schedule = %Schedule{time_zone: "Europe/Madrid"}
      starts_at = build_dt(~N[2026-03-16 09:00:00])
      ends_at = build_dt(~N[2026-03-16 17:00:00])

      assert Duration.between(schedule, starts_at, ends_at) == 0
    end

    test "calculates duration within a single business day slot" do
      # Monday 10:00 to 13:00 — fully within the 09:00-14:00 slot
      starts_at = build_dt(~N[2026-03-16 10:00:00])
      ends_at = build_dt(~N[2026-03-16 13:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 3 * 3600
    end

    test "calculates duration spanning multiple intervals in the same day" do
      # Monday 10:00 to 18:00 — spans the 09:00-14:00 and 15:00-20:00 slots
      # Business time: 10:00-14:00 (4h) + 15:00-18:00 (3h) = 7h
      starts_at = build_dt(~N[2026-03-16 10:00:00])
      ends_at = build_dt(~N[2026-03-16 18:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 7 * 3600
    end

    test "clamps start when it falls before business hours" do
      # Monday 07:00 to 12:00 — business starts at 09:00
      # Business time: 09:00-12:00 = 3h
      starts_at = build_dt(~N[2026-03-16 07:00:00])
      ends_at = build_dt(~N[2026-03-16 12:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 3 * 3600
    end

    test "clamps end when it falls after business hours" do
      # Monday 16:00 to 23:00 — business ends at 20:00
      # Business time: 16:00-20:00 = 4h
      starts_at = build_dt(~N[2026-03-16 16:00:00])
      ends_at = build_dt(~N[2026-03-16 23:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 4 * 3600
    end

    test "returns 0 when both times are outside business hours" do
      # Monday 21:00 to 23:00 — after closing
      starts_at = build_dt(~N[2026-03-16 21:00:00])
      ends_at = build_dt(~N[2026-03-16 23:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 0
    end

    test "returns 0 when range falls in the gap between intervals" do
      # Monday 14:00 to 15:00 — in the break between morning and afternoon slots
      starts_at = build_dt(~N[2026-03-16 14:00:00])
      ends_at = build_dt(~N[2026-03-16 15:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 0
    end

    test "spans multiple business days" do
      # Monday 16:00 to Tuesday 11:00
      # Monday: 16:00-20:00 = 4h
      # Tuesday: 09:00-11:00 = 2h
      # Total: 6h
      starts_at = build_dt(~N[2026-03-16 16:00:00])
      ends_at = build_dt(~N[2026-03-17 11:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 6 * 3600
    end

    test "excludes weekends" do
      # Friday 16:00 to Monday 11:00
      # Friday: 16:00-20:00 = 4h
      # Saturday & Sunday: 0h (no hours configured)
      # Monday: 09:00-11:00 = 2h
      # Total: 6h
      starts_at = build_dt(~N[2026-03-20 16:00:00])
      ends_at = build_dt(~N[2026-03-23 11:00:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 6 * 3600
    end

    test "excludes holidays" do
      schedule = %{@schedule | holidays: [~D[2026-03-17]]}

      # Monday 16:00 to Wednesday 11:00
      # Monday: 16:00-20:00 = 4h
      # Tuesday (holiday): 0h
      # Wednesday: 09:00-11:00 = 2h
      # Total: 6h
      starts_at = build_dt(~N[2026-03-16 16:00:00])
      ends_at = build_dt(~N[2026-03-18 11:00:00])

      assert Duration.between(schedule, starts_at, ends_at) == 6 * 3600
    end

    test "excludes break time" do
      schedule = %{@schedule | breaks: [{~D[2026-03-16], [{~T[11:00:00], ~T[12:00:00]}]}]}

      # Monday 10:00 to 13:00 with a break 11:00-12:00
      # Business time: 10:00-11:00 (1h) + 12:00-13:00 (1h) = 2h
      starts_at = build_dt(~N[2026-03-16 10:00:00])
      ends_at = build_dt(~N[2026-03-16 13:00:00])

      assert Duration.between(schedule, starts_at, ends_at) == 2 * 3600
    end

    test "uses shift intervals instead of regular hours" do
      schedule = %{@schedule | shifts: [{~D[2026-03-16], [{~T[10:00:00], ~T[14:00:00]}]}]}

      # Monday has a shift: only 10:00-14:00 (instead of regular 09:00-14:00 + 15:00-20:00)
      # Range: 09:00 to 20:00
      # Business time: 10:00-14:00 = 4h
      starts_at = build_dt(~N[2026-03-16 09:00:00])
      ends_at = build_dt(~N[2026-03-16 20:00:00])

      assert Duration.between(schedule, starts_at, ends_at) == 4 * 3600
    end

    test "handles cross-timezone inputs" do
      # Schedule is in Europe/Madrid (UTC+1 in winter)
      # Input datetimes in UTC: Monday 08:00 UTC = 09:00 Madrid, 12:00 UTC = 13:00 Madrid
      # Business time: 09:00-13:00 Madrid = 4h
      starts_at = DateTime.from_naive!(~N[2026-03-16 08:00:00], "Etc/UTC")
      ends_at = DateTime.from_naive!(~N[2026-03-16 12:00:00], "Etc/UTC")

      assert Duration.between(@schedule, starts_at, ends_at) == 4 * 3600
    end

    test "full business week duration" do
      # Monday 00:00 to Friday 23:59 — covers the entire week
      # Each day: 09:00-14:00 (5h) + 15:00-20:00 (5h) = 10h
      # 5 days * 10h = 50h
      starts_at = build_dt(~N[2026-03-16 00:00:00])
      ends_at = build_dt(~N[2026-03-20 23:59:00])

      assert Duration.between(@schedule, starts_at, ends_at) == 50 * 3600
    end
  end

  defp build_dt(naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Europe/Madrid", Tzdata.TimeZoneDatabase)
  end
end
