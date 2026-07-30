# Upgrading to v1.0

OpenHours no longer ships with a time zone database — if this update breaks your project, please add one to your dependencies and set `config :elixir, :time_zone_database, Tz.TimeZoneDatabase`. You can use `tz` or any other library implementing the `Calendar.TimeZoneDatabase` behaviour, such as `tzdata` or `time_zone_info`.
