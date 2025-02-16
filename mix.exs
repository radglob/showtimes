defmodule Showtimes.MixProject do
  use Mix.Project

  def project do
    [
      app: :showtimes,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 2.2.1"},
      {:floki, "~> 0.37.0"},
      {:tzdata, "~> 1.1"}
    ]
  end
end
