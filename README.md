
# OpenHours
[![Build Status](https://github.com/hopsor/open_hours/actions/workflows/ci.yml/badge.svg)](https://github.com/hopsor/open_hours/actions?query=workflow%3A%22CI%22) [![Package Version](https://img.shields.io/hexpm/v/open_hours.svg?color=purple)](https://hex.pm/packages/open_hours)

OpenHours is an Elixir package aimed to help with time calculations using business hours.

It's inspired by the amazing ruby gem [biz](https://github.com/zendesk/biz) developed by Zendesk.

## Installation

The package can be installed by adding `open_hours` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:open_hours, "~> 0.1.0"}
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

OpenHours offers two main functionalities.

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

## License

This software is licensed under the [MIT license](LICENSE.md).
