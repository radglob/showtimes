import Config

config :elixir, :time_zone_database,Tzdata.TimeZoneDatabase

config :showtimes, ecto_repos: [Showtimes.Repo]

config :showtimes, Showtimes.Repo, database: "showtimes.db"
