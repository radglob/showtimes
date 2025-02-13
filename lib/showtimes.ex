defmodule Showtimes do
  alias HTTPoison
  alias Floki

  alias Showtimes.Parser

  @moduledoc """
  Documentation for `Showtimes`.
  """

  @url "https://baltshowplace.tumblr.com"
  @months ~w(January February March April May June July August September October November December)

  def main do
    {:ok, resp} = HTTPoison.get(@url)
    {:ok, doc} = Floki.parse_document(resp.body)
    post = Floki.find(doc, ".post")
    # hash = hash_document(Floki.raw_html(post))
    # Check hash against database, write if different.
    events = parse_events(post)
    today = Date.utc_today() |> Date.to_string()

    IO.puts("Events on #{today}:")
    Enum.each(events[today], fn %{
                                  performers: performers,
                                  time: time,
                                  price: price,
                                  location: location
                                } ->
      IO.puts("#{performers} at #{location}, #{time}, #{price}")
    end)
  end

  def parse_events(post) do
    Floki.find(post, "h2:not(.title), p")
    |> Enum.chunk_by(fn {node_type, _, _} -> node_type == "h2" end)
    |> Enum.chunk_every(2)
    |> Enum.map(fn [h2, ps] ->
      {:ok, date} =
        h2
        |> List.first()
        |> Floki.text()
        |> parse_date()

      if is_nil(date) do
        nil
      else
        events =
          Enum.map(ps, fn p -> p |> Floki.text() |> Parser.parse_event() end) |> Enum.filter(& &1)

        {Date.to_string(date), events}
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.into(%{})
  end

  @doc """
  Parses dates from strings in the form of "(day of week), (month) (date day), (year) to Date structs."

  ## Examples

    iex> Showtimes.parse_date("Saturday, February 15, 2025")
    {:ok, ~D[2025-02-15]}

    iex> Showtimes.parse_date("Sunday, February 30, 2025")
    {:error, :invalid_date}
  """
  def parse_date("\n"), do: {:ok, nil}

  def parse_date(s) do
    [_, month_day, year] = String.split(s, ", ")

    [month, day] =
      month_day
      |> String.trim()
      |> String.split(" ")

    month = Enum.find_index(@months, fn m -> m == month end) + 1
    Date.new(String.to_integer(year), month, String.to_integer(day))
  end

  defp hash_document(html) do
    :crypto.hash(:md5, html)
    |> Base.encode16()
    |> String.downcase()
  end
end
