defmodule Showtimes.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :performers, :string
      add :location, :string
      add :advance_price, :integer
      add :alternate_price, :string
      add :min_price, :integer
      add :max_price, :integer
      add :door_price, :integer
      add :duration, :integer
      add :sold_out, :boolean, default: false
      add :start_time, :utc_datetime
      add :date, :date

      timestamps()
    end

    create unique_index(:events, [:performers, :location, :start_time])
  end
end
