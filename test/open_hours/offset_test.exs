defmodule OpenHours.OffsetTest do
  use ExUnit.Case

  alias OpenHours.{Offset, Schedule}

  # Week of 2019-01-14 (Monday):
  # Mon-Fri: 09:00-14:00, 15:00-20:00 (10h/day)
  # Tuesday 2019-01-15: holiday
  # Wednesday 2019-01-16: break 17:00-20:00 (second slot becomes 15:00-17:00, 7h total)
  # Friday 2019-01-18: shift 10:00-14:00 (4h total)
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

  describe "shift/3 forward" do
    test "within the same slot" do
      # Wed 10:00 + 2h = Wed 12:00 (within 09:00-14:00)
      dt = build_dt(~N[2019-01-16 10:00:00])
      assert Offset.shift(@schedule, dt, {2, :hour}) == build_dt(~N[2019-01-16 12:00:00])
    end

    test "spans across slots in the same day" do
      # Wed 13:00 + 3h: 1h left in 09-14, gap, 2h into 15-17 = Wed 17:00
      dt = build_dt(~N[2019-01-16 13:00:00])
      assert Offset.shift(@schedule, dt, {3, :hour}) == build_dt(~N[2019-01-16 17:00:00])
    end

    test "spans across days" do
      # Wed 16:00 + 3h: 1h left in 15-17, then Thu 09-14: 2h in = Thu 11:00
      dt = build_dt(~N[2019-01-16 16:00:00])
      assert Offset.shift(@schedule, dt, {3, :hour}) == build_dt(~N[2019-01-17 11:00:00])
    end

    test "snaps to next business moment when starting outside hours" do
      # Wed 14:30 + 2h: snaps to 15:00, then 2h into 15-17 = Wed 17:00
      dt = build_dt(~N[2019-01-16 14:30:00])
      assert Offset.shift(@schedule, dt, {2, :hour}) == build_dt(~N[2019-01-16 17:00:00])
    end

    test "skips holidays" do
      # Mon 19:00 + 2h: 1h left in Mon 15-20, Tue is holiday, 1h into Wed 09-14 = Wed 10:00
      dt = build_dt(~N[2019-01-14 19:00:00])
      assert Offset.shift(@schedule, dt, {2, :hour}) == build_dt(~N[2019-01-16 10:00:00])
    end

    test "respects shifts" do
      # Fri 11:00 + 2h: within shift 10-14, result = Fri 13:00
      dt = build_dt(~N[2019-01-18 11:00:00])
      assert Offset.shift(@schedule, dt, {2, :hour}) == build_dt(~N[2019-01-18 13:00:00])
    end

    test "respects breaks" do
      # Wed 16:30 + 1h: only 30min left in 15-17 (break cuts 17-20), 30min into Thu 09-14 = Thu 09:30
      dt = build_dt(~N[2019-01-16 16:30:00])
      assert Offset.shift(@schedule, dt, {1, :hour}) == build_dt(~N[2019-01-17 09:30:00])
    end

    test "skips weekends" do
      # Fri 13:00 + 3h: 1h left in shift 10-14, no Sat/Sun, Mon 09 + 2h = Mon 11:00
      dt = build_dt(~N[2019-01-18 13:00:00])
      assert Offset.shift(@schedule, dt, {3, :hour}) == build_dt(~N[2019-01-21 11:00:00])
    end

    test "with minutes unit" do
      # Wed 13:45 + 30min: 15min left in 09-14, gap, 15min into 15-17 = Wed 15:15
      dt = build_dt(~N[2019-01-16 13:45:00])
      assert Offset.shift(@schedule, dt, {30, :minute}) == build_dt(~N[2019-01-16 15:15:00])
    end
  end

  describe "shift/3 backward" do
    test "within the same slot" do
      # Wed 12:00 - 2h = Wed 10:00 (within 09:00-14:00)
      dt = build_dt(~N[2019-01-16 12:00:00])
      assert Offset.shift(@schedule, dt, {-2, :hour}) == build_dt(~N[2019-01-16 10:00:00])
    end

    test "spans across slots in the same day" do
      # Wed 16:00 - 3h: 1h back in 15-17 (to 15:00), gap, 2h back in 09-14 (from 14:00) = Wed 12:00
      dt = build_dt(~N[2019-01-16 16:00:00])
      assert Offset.shift(@schedule, dt, {-3, :hour}) == build_dt(~N[2019-01-16 12:00:00])
    end

    test "spans across days" do
      # Thu 10:00 - 7h: 1h back in Thu 09-10, then Wed 15-17 (2h), then Wed 09-14: 4h from end = Wed 10:00
      dt = build_dt(~N[2019-01-17 10:00:00])
      assert Offset.shift(@schedule, dt, {-7, :hour}) == build_dt(~N[2019-01-16 10:00:00])
    end

    test "snaps to previous business moment when starting outside hours" do
      # Wed 14:30 - 2h: snaps to 14:00, then 2h back in 09-14 = Wed 12:00
      dt = build_dt(~N[2019-01-16 14:30:00])
      assert Offset.shift(@schedule, dt, {-2, :hour}) == build_dt(~N[2019-01-16 12:00:00])
    end

    test "skips holidays" do
      # Wed 10:00 - 2h: 1h back in Wed 09-10, Tue is holiday, 1h back in Mon 15-20 (from 20:00) = Mon 19:00
      dt = build_dt(~N[2019-01-16 10:00:00])
      assert Offset.shift(@schedule, dt, {-2, :hour}) == build_dt(~N[2019-01-14 19:00:00])
    end

    test "skips weekends" do
      # Mon 2019-01-21 10:00 - 3h: 1h back Mon 09-10, no Sat/Sun, Fri has shift 10-14 (4h),
      # 2h from end = Fri 12:00
      dt = build_dt(~N[2019-01-21 10:00:00])
      assert Offset.shift(@schedule, dt, {-3, :hour}) == build_dt(~N[2019-01-18 12:00:00])
    end

    test "with minutes unit" do
      # Wed 15:15 - 30min: 15min back in 15-17 (to 15:00), gap, 15min back in 09-14 = Wed 13:45
      dt = build_dt(~N[2019-01-16 15:15:00])
      assert Offset.shift(@schedule, dt, {-30, :minute}) == build_dt(~N[2019-01-16 13:45:00])
    end
  end

  describe "shift/3 with different timezone" do
    test "converts datetime to schedule timezone before calculating" do
      # Wed 09:00 UTC = Wed 10:00 Europe/Madrid (CET = UTC+1)
      # 10:00 Madrid + 2h = 12:00 Madrid
      dt = DateTime.from_naive!(~N[2019-01-16 09:00:00], "Etc/UTC")
      result = Offset.shift(@schedule, dt, {2, :hour})
      assert result == build_dt(~N[2019-01-16 12:00:00])
    end
  end

  describe "shift/3 edge cases" do
    test "starting exactly at slot boundary (start)" do
      # Wed 09:00 + 1h = Wed 10:00
      dt = build_dt(~N[2019-01-16 09:00:00])
      assert Offset.shift(@schedule, dt, {1, :hour}) == build_dt(~N[2019-01-16 10:00:00])
    end

    test "starting exactly at slot boundary (end)" do
      # Wed 14:00 + 1h: at boundary of 09-14, snaps forward to 15:00, then 1h = 16:00
      dt = build_dt(~N[2019-01-16 14:00:00])
      assert Offset.shift(@schedule, dt, {1, :hour}) == build_dt(~N[2019-01-16 16:00:00])
    end

    test "duration exactly consumes a full slot" do
      # Wed 15:00 + 2h = Wed 17:00 (exactly consumes 15:00-17:00 due to break)
      dt = build_dt(~N[2019-01-16 15:00:00])
      assert Offset.shift(@schedule, dt, {2, :hour}) == build_dt(~N[2019-01-16 17:00:00])
    end

    test "large duration spanning multiple days" do
      # Mon 09:00 + 20h:
      # Mon: 09-14 (5h) + 15-20 (5h) = 10h. Remaining: 10h
      # Tue: holiday. Remaining: 10h
      # Wed: 09-14 (5h) + 15-17 (2h) = 7h. Remaining: 3h
      # Thu: 09-14, 3h in = Thu 12:00
      dt = build_dt(~N[2019-01-14 09:00:00])
      assert Offset.shift(@schedule, dt, {20, :hour}) == build_dt(~N[2019-01-17 12:00:00])
    end
  end

  describe "shift/3 error handling" do
    test "raises on unsupported unit" do
      dt = build_dt(~N[2019-01-16 10:00:00])

      assert_raise ArgumentError, "unsupported unit :day, expected :hour or :minute", fn ->
        Offset.shift(@schedule, dt, {1, :day})
      end
    end

    test "raises on zero amount" do
      dt = build_dt(~N[2019-01-16 10:00:00])

      assert_raise ArgumentError, "amount must be a non-zero integer, got: 0", fn ->
        Offset.shift(@schedule, dt, {0, :hour})
      end
    end

    test "raises on empty schedule" do
      empty = %Schedule{time_zone: "Europe/Madrid"}
      dt = build_dt(~N[2019-01-16 10:00:00])

      assert_raise ArgumentError, "no business hours available in the schedule", fn ->
        Offset.shift(empty, dt, {1, :hour})
      end
    end
  end

  defp build_dt(naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Europe/Madrid", Tzdata.TimeZoneDatabase)
  end
end
