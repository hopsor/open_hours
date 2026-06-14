defmodule OpenHours.TimeZoneDatabase do
  @moduledoc """
  Resolves the configured `Calendar.TimeZoneDatabase` implementation.

  By default, the Elixir global time zone database is used (set via
  `Calendar.put_time_zone_database/1`). You can override this for OpenHours
  specifically by setting:

      config :open_hours, :time_zone_database, Tz.TimeZoneDatabase

  Any module that implements the `Calendar.TimeZoneDatabase` behaviour can be used.
  """

  @doc """
  Returns the configured time zone database module.
  """
  @spec database() :: module()
  def database do
    Application.get_env(:open_hours, :time_zone_database, Calendar.get_time_zone_database())
  end
end
