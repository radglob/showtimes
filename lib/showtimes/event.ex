defmodule Showtimes.Event do
  use Ecto.Schema

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
end
