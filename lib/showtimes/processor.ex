defmodule Showtimes.Processor do
  @price_defaults %{
    min_price: nil,
    max_price: nil,
    alternate_price: nil,
    advance_price: nil,
    door_price: nil,
    sold_out: false
  }

  @doc """
  ## Examples
    iex> Showtimes.Processor.process_event(%{performers: "Thonian Horde, The Edge Of Desolation, Chiaroscuro, Revvnant", time: "7PM", price: "$15", location: "Ottobar" }, ~D[2025-02-26])
    [%{performers: "Thonian Horde, The Edge Of Desolation, Chiaroscuro, Revvnant", location: "Ottobar", advance_price: nil, alternate_price: nil, door_price: nil, duration: nil, max_price: nil, min_price: 1500, sold_out: false, start_time: ~U[2025-02-27 00:00:00Z], date: ~D[2025-02-26]}]

  """
  def process_event(event, date) do
    %{start_times: start_times, duration: duration} = process_time(event[:time], date)

    case start_times do
      [] ->
        [
          %{
            performers: event[:performers],
            location: event[:location],
            date: date,
            sold_out: event[:sold_out],
            duration: duration
          }
          |> Map.merge(process_price(event[:price]))
        ]

      _ ->
        Enum.map(start_times, fn time ->
          %{
            performers: event[:performers],
            location: event[:location],
            date: date,
            sold_out: event[:sold_out],
            duration: duration,
            start_time: time
          }
          |> Map.merge(process_price(event[:price]))
        end)
    end
  end

  defp process_decimal(s) do
    s
    |> Float.parse()
    |> elem(0)
    |> (fn n -> n * 100 end).()
    |> trunc()
  end

  @doc """
  ## Examples
    iex> Showtimes.Processor.process_price("$7")
    %{min_price: 700, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$7.01")
    %{min_price: 701, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$10")
    %{min_price: 1000, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$10.01")
    %{min_price: 1001, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$7-$10")
    %{min_price: 700, max_price: 1000, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$7.07-$10.01")
    %{min_price: 707, max_price: 1001, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$10-$15")
    %{min_price: 1000, max_price: 1500, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$10 adv/$20 doors")
    %{min_price: nil, max_price: nil, alternate_price: nil, door_price: 2000, advance_price: 1000, sold_out: false}
    iex> Showtimes.Processor.process_price("$10 (or clothing donation)")
    %{min_price: 1000, max_price: nil, alternate_price: "(or clothing donation)", door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$SOLD OUT")
    %{min_price: nil, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: true}
    iex> Showtimes.Processor.process_price("$Donations")
    %{min_price: nil, max_price: nil, alternate_price: "Donations", door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$FREE")
    %{min_price: nil, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
  """

  def process_price(price) do
    parts = String.split(price, " ")

    case parts do
      ["$FREE"] ->
        @price_defaults

      ["$Donations"] ->
        Map.merge(@price_defaults, %{alternate_price: "Donations"})

      [s] ->
        case String.split(s, "-") do
          [p] ->
            <<"$", n::binary>> = p
            Map.merge(@price_defaults, %{min_price: process_decimal(n)})

          [min_price, max_price] ->
            <<"$", min::binary>> = min_price
            <<"$", max::binary>> = max_price

            Map.merge(@price_defaults, %{
              min_price: process_decimal(min),
              max_price: process_decimal(max)
            })
        end

      ["$SOLD", "OUT"] ->
        Map.merge(@price_defaults, %{sold_out: true})

      [advance_price, mid, "doors"] ->
        <<"$", advance_price::binary>> = advance_price
        <<"adv/$", door_price::binary>> = mid

        Map.merge(@price_defaults, %{
          advance_price: process_decimal(advance_price),
          door_price: process_decimal(door_price)
        })

      [maybe_price | rest] ->
        <<"$", min_price::binary>> = maybe_price
        alternate_price = Enum.join(rest, " ")

        Map.merge(@price_defaults, %{
          min_price: process_decimal(min_price),
          alternate_price: alternate_price
        })
    end
  end

  @doc """
  ## Examples
    iex> Showtimes.Processor.process_time(nil, "")
    %{start_times: [], duration: nil}

    iex> Showtimes.Processor.process_time("", "")
    %{start_times: [], duration: nil}

    iex> Showtimes.Processor.process_time("9AM", ~D[2025-02-01])
    %{start_times: [~U[2025-02-01 14:00:00Z]], duration: nil}

    iex> Showtimes.Processor.process_time("9AM-12PM", ~D[2025-02-01])
    %{start_times: [~U[2025-02-01 14:00:00Z]], duration: 10800}

    iex> Showtimes.Processor.process_time("7:30PM & 9PM", ~D[2025-02-01])
    %{start_times: [~U[2025-02-02 00:30:00Z], ~U[2025-02-02 02:00:00Z]], duration: nil}
  """
  def process_time(nil, _), do: %{start_times: [], duration: nil}
  def process_time("", _), do: %{start_times: [], duration: nil}

  def process_time(time, date) do
    cond do
      String.contains?(time, "-") ->
        times =
          time
          |> String.split("-")
          |> Enum.map(&do_process_time(&1, date))

        duration = DateTime.diff(Enum.at(times, 1), Enum.at(times, 0))
        %{start_times: [Enum.at(times, 0)], duration: duration}

      String.contains?(time, " & ") ->
        times =
          time
          |> String.split(" & ")
          |> Enum.map(&do_process_time(&1, date))

        %{start_times: times, duration: nil}

      true ->
        times = [do_process_time(time, date)]
        %{start_times: times, duration: nil}
    end
  end

  @doc """
  ## Examples
    iex> Showtimes.Processor.do_process_time("9AM", ~D[2025-02-01])
    ~U[2025-02-01 14:00:00Z]

    iex> Showtimes.Processor.do_process_time("9:30AM", ~D[2025-02-01])
    ~U[2025-02-01 14:30:00Z]

    iex> Showtimes.Processor.do_process_time("5:30PM", ~D[2025-02-01])
    ~U[2025-02-01 22:30:00Z]

    iex> Showtimes.Processor.do_process_time("12:30PM", ~D[2025-02-01])
    ~U[2025-02-01 17:30:00Z]
  """
  def do_process_time("N/A", _date), do: nil

  def do_process_time(time, date) do
    case time do
      <<hour::binary-size(1), meridian::binary-size(2)>> ->
        hour = String.to_integer(hour)

        hour =
          if meridian == "PM" && hour < 12 do
            hour + 12
          else
            hour
          end

        t = Time.new!(hour, 0, 0)
        DateTime.new!(date, t, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")

      <<hour::binary-size(2), meridian::binary-size(2)>> ->
        hour = String.to_integer(hour)

        hour =
          if meridian == "PM" && hour < 12 do
            hour + 12
          else
            hour
          end

        t = Time.new!(hour, 0, 0)
        DateTime.new!(date, t, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")

      <<hour::binary-size(1), ":", minutes::binary-size(2), meridian::binary-size(2)>> ->
        hour = String.to_integer(hour)

        hour =
          if meridian == "PM" && hour < 12 do
            hour + 12
          else
            hour
          end

        minutes = String.to_integer(minutes)
        t = Time.new!(hour, minutes, 0)
        DateTime.new!(date, t, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")

      <<hour::binary-size(2), ":", minutes::binary-size(2), meridian::binary-size(2)>> ->
        hour = String.to_integer(hour)

        hour =
          if meridian == "PM" && hour < 12 do
            hour + 12
          else
            hour
          end

        minutes = String.to_integer(minutes)
        t = Time.new!(hour, minutes, 0)
        DateTime.new!(date, t, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")
    end
  end
end
