defmodule Showtimes.Application do
  def start(), do: start(nil, nil)

  def start(_type, _args) do
    children = [
      Showtimes.Repo
    ]

    opts = [strategy: :one_for_one, name: Showtimes.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
