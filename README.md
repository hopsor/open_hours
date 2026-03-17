
# OpenHours
[![Build Status](https://github.com/hopsor/open_hours/actions/workflows/ci.yml/badge.svg)](https://github.com/hopsor/open_hours/actions?query=workflow%3A%22CI%22) [![Package Version](https://img.shields.io/hexpm/v/open_hours.svg?color=purple)](https://hex.pm/packages/open_hours)

OpenHours is an Elixir package aimed to help with time calculations using business hours.

It's inspired by the amazing ruby gem [biz](https://github.com/zendesk/biz) developed by Zendesk.

## Installation

The package can be installed by adding `open_hours` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:open_hours, "~> 0.2.0"}
  ]
end
```

## Usage

In order to use OpenHours functions you first need a `Schedule` config:

```elixir
schedule = %OpenHours.Schedule{
  hours: %{
    mon: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
    tue: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
    wed: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}],
    thu: [{~T[09:00:00], ~T[14:00:00]}, {~T[15:00:00], ~T[20:00:00]}]
  },
  holidays: [
    ~D[2019-01-14]
  ],
  shifts: [
    {~D[2019-01-15], [{~T[10:00:00], ~T[15:00:00]}]}
  ],
  breaks: [
    {~D[2019-01-16], [{~T[17:00:00], ~T[20:00:00]}]}
  ],
  time_zone: "Europe/Madrid"
}
```

There are five settings to configure in a schedule:

- `hours`: Map containing all the open hours intervals for a regular week.
- `holidays`: List of dates in which the business is closed.
- `shifts`: Special dates where the business has a different hour schedule.
- `breaks`: Special dates where the business has interruption intervals.
- `time_zone`: Time zone of the schedule.

OpenHours offers the following functionalities.

### Checking a DateTime is within open hours

```elixir
> at = DateTime.from_naive!(~N[2019-01-15 14:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-15 14:00:00+01:00 CET Europe/Madrid>

> OpenHours.Schedule.in_hours?(schedule, at)
true

> at = DateTime.from_naive!(~N[2019-01-14 12:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-14 12:00:00+01:00 CET Europe/Madrid>

> OpenHours.Schedule.in_hours?(schedule, at)
false
```

### Calculate all TimeSlot between two dates

```elixir
> starts_at = DateTime.from_naive!(~N[2019-01-14 12:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-14 12:00:00+01:00 CET Europe/Madrid>

> ends_at = DateTime.from_naive!(~N[2019-01-16 22:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-16 22:00:00+01:00 CET Europe/Madrid>

> OpenHours.TimeSlot.between(schedule, starts_at, ends_at)
[
  %OpenHours.TimeSlot{
    ends_at: #DateTime<2019-01-15 15:00:00+01:00 CET Europe/Madrid>,
    starts_at: #DateTime<2019-01-15 10:00:00+01:00 CET Europe/Madrid>
  },
  %OpenHours.TimeSlot{
    ends_at: #DateTime<2019-01-16 14:00:00+01:00 CET Europe/Madrid>,
    starts_at: #DateTime<2019-01-16 09:00:00+01:00 CET Europe/Madrid>
  },
  %OpenHours.TimeSlot{
    ends_at: #DateTime<2019-01-16 17:00:00+01:00 CET Europe/Madrid>,
    starts_at: #DateTime<2019-01-16 15:00:00+01:00 CET Europe/Madrid>
  }
]
```

### Calculate business time duration

Use `OpenHours.Duration.between/3` to calculate the amount of business time (in seconds) between two DateTimes. Non-working hours, weekends, holidays, and breaks are excluded.

```elixir
> starts_at = DateTime.from_naive!(~N[2019-01-15 10:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-15 10:00:00+01:00 CET Europe/Madrid>

> ends_at = DateTime.from_naive!(~N[2019-01-16 11:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-16 11:00:00+01:00 CET Europe/Madrid>

> OpenHours.Duration.between(schedule, starts_at, ends_at)
25200
```

### Find next and previous time slots

Use `OpenHours.TimeSlot.next/3` and `OpenHours.TimeSlot.previous/3` to find upcoming or past time slots from a given DateTime.

```elixir
> at = DateTime.from_naive!(~N[2019-01-14 12:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-14 12:00:00+01:00 CET Europe/Madrid>

> OpenHours.TimeSlot.next(schedule, at, limit: 2)
[
  %OpenHours.TimeSlot{
    starts_at: #DateTime<2019-01-15 10:00:00+01:00 CET Europe/Madrid>,
    ends_at: #DateTime<2019-01-15 15:00:00+01:00 CET Europe/Madrid>
  },
  %OpenHours.TimeSlot{
    starts_at: #DateTime<2019-01-16 09:00:00+01:00 CET Europe/Madrid>,
    ends_at: #DateTime<2019-01-16 14:00:00+01:00 CET Europe/Madrid>
  }
]

> OpenHours.TimeSlot.previous(schedule, at, limit: 1)
[
  %OpenHours.TimeSlot{
    starts_at: #DateTime<2019-01-10 15:00:00+01:00 CET Europe/Madrid>,
    ends_at: #DateTime<2019-01-10 20:00:00+01:00 CET Europe/Madrid>
  }
]
```

### Shift a DateTime by business time

Use `OpenHours.Offset.shift/3` to shift a DateTime forward or backward by a given amount of business time. The result skips over non-working hours, weekends, holidays, and breaks.

```elixir
> at = DateTime.from_naive!(~N[2019-01-15 14:00:00], "Europe/Madrid", Tzdata.TimeZoneDatabase)
#DateTime<2019-01-15 14:00:00+01:00 CET Europe/Madrid>

> OpenHours.Offset.shift(schedule, at, {2, :hour})
#DateTime<2019-01-16 10:00:00+01:00 CET Europe/Madrid>

> OpenHours.Offset.shift(schedule, at, {-3, :hour})
#DateTime<2019-01-15 11:00:00+01:00 CET Europe/Madrid>
```

## License

This software is licensed under the [MIT license](LICENSE.md).
