defmodule OpenHours.Common do
  def weekday(at) do
    at
    |> Date.day_of_week()
    |> day_index_to_atom()
  end

  def day_index_to_atom(index) do
    case index do
      1 -> :mon
      2 -> :tue
      3 -> :wed
      4 -> :thu
      5 -> :fri
      6 -> :sat
      7 -> :sun
    end
  end
end
