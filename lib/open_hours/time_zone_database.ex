defmodule OpenHours.TimeZoneDatabase do
  @moduledoc """
  Resolves the configured `Calendar.TimeZoneDatabase` implementation.

  By default, `Tzdata.TimeZoneDatabase` is used. You can override this by setting:

      config :open_hours, :time_zone_database, Tz.TimeZoneDatabase

  Any module that implements the `Calendar.TimeZoneDatabase` behaviour can be used.
  """

  @doc """
  Returns the configured time zone database module.
  """
  @spec database() :: module()
  def database do
    Application.get_env(:open_hours, :time_zone_database, Tzdata.TimeZoneDatabase)
  end
end
