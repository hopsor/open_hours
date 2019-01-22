defmodule OpenHours.IntervalTest do
  use ExUnit.Case

  alias OpenHours.Interval

  describe "difference/2 when arguments are intervals" do
    test "when there isn't overlapping it returns a list with the first interval" do
      a = {~T[09:00:00], ~T[12:00:00]}
      b = {~T[15:00:00], ~T[20:00:00]}

      expected_output = [a]

      assert Interval.difference(a, b) == expected_output
    end

    test "when there's overlapping it returns a list of intervals without the overlap" do
      a = {~T[09:00:00], ~T[20:00:00]}
      b = {~T[12:00:00], ~T[15:00:00]}

      expected_output = [
        {~T[09:00:00], ~T[12:00:00]},
        {~T[15:00:00], ~T[20:00:00]}
      ]

      assert Interval.difference(a, b) == expected_output
    end
  end

  describe "difference/2 when arguments are lists of intervals" do
    test "returns proper result when the two set of intervals overlaps" do
      a = [{~T[09:00:00], ~T[22:00:00]}]
      b = [{~T[10:00:00], ~T[12:00:00]}, {~T[18:00:00], ~T[20:00:00]}]

      expected_output = [
        {~T[09:00:00], ~T[10:00:00]},
        {~T[12:00:00], ~T[18:00:00]},
        {~T[20:00:00], ~T[22:00:00]}
      ]

      assert Interval.difference(a, b) == expected_output
    end

    test "returns proper result when the two sets of intervals don't overlap" do
      a = [{~T[09:00:00], ~T[12:00:00]}]
      b = [{~T[12:00:00], ~T[14:00:00]}, {~T[18:00:00], ~T[20:00:00]}]

      expected_output = [
        {~T[09:00:00], ~T[12:00:00]}
      ]

      assert Interval.difference(a, b) == expected_output
    end

    test "returns an empty list when both intervals completely overlap" do
      a = [{~T[01:00:00], ~T[23:00:00]}]
      b = [{~T[00:00:00], ~T[14:00:00]}, {~T[14:00:00], ~T[23:00:00]}]

      expected_output = []

      assert Interval.difference(a, b) == expected_output
    end
  end
end
