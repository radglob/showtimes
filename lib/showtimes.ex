defmodule Showtimes do
  alias HTTPoison
  alias Floki

  import Ecto.Query

  alias Showtimes.Event
  alias Showtimes.Parser
  alias Showtimes.Processor
  alias Showtimes.Repo

  @moduledoc """
  Documentation for `Showtimes`.
  """

  @url "https://baltshowplace.tumblr.com"
  @months ~w(January February March April May June July August September October November December)
  @timezone "America/New_York"

  def main do
    {:ok, resp} = HTTPoison.get(@url)
    {:ok, doc} = Floki.parse_document(resp.body)
    post = Floki.find(doc, ".post")
    # hash = hash_document(Floki.raw_html(post))
    # Check hash against database, write if different.
    handle_events(post)

    today = DateTime.now!(@timezone) |> DateTime.to_date()
    query = from(e in Event, where: e.date == ^today)
    events = Repo.all(query)

    IO.puts("Events on #{today}:")

    Enum.each(events, fn event ->
      IO.puts(event)
    end)
  end

  def handle_events(post) do
    events =
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
          ps
          |> Enum.map(fn p ->
            text =
              p |> Floki.text() |> String.trim()

            if text != "" do
              text |> Parser.parse_event() |> Processor.process_event(date)
            end
          end)
        end
      end)
      |> List.flatten()
      |> Enum.filter(& &1)

    Enum.each(events, fn event ->
      %Event{}
      |> Event.changeset(event)
      |> Repo.insert()
    end)
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
    :crypto.hash(:sha256, html)
    |> Base.encode16()
    |> String.downcase()
  end
end
