defmodule Showtimes.Event do
  use Ecto.Schema

  import Showtimes.TimeHelpers, only: [time_with_duration: 2]

  import Ecto.Changeset

  schema "events" do
    field(:performers, :string)
    field(:location, :string)
    field(:advance_price, :integer)
    field(:alternate_price, :string)
    field(:min_price, :integer)
    field(:max_price, :integer)
    field(:door_price, :integer)
    field(:duration, :integer)
    field(:sold_out, :boolean, default: false)
    field(:start_time, :utc_datetime)
    field(:date, :date)

    timestamps()
  end

  def changeset(event, params \\ %{}) do
    event
    |> cast(params, [
      :performers,
      :location,
      :advance_price,
      :alternate_price,
      :min_price,
      :max_price,
      :door_price,
      :duration,
      :sold_out,
      :start_time,
      :date
    ])
    |> validate_required([:performers, :location, :date])
    |> unique_constraint([:performers, :location, :start_time])
  end

  defimpl String.Chars, for: Showtimes.Event do
    def to_string(%{performers: performers, location: location, date: date, start_time: nil}) do
      "#{performers} at #{location} on #{date} (contact venue for time)"
    end

    def to_string(%{
          performers: performers,
          location: location,
          start_time: start_time,
          duration: duration
        }) do
      "#{performers} at #{location} on #{time_with_duration(start_time, duration)}"
    end
  end
end
