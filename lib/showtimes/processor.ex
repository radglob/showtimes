defmodule Showtimes.Processor do
  @doc """
  ## Examples
    iex> Showtimes.Processor.process_price("$7")
    %{min_price: 700, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$10")
    %{min_price: 1000, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$7-$10")
    %{min_price: 700, max_price: 1000, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$10-$15")
    %{min_price: 1000, max_price: 1500, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$10 adv/$20 doors")
    %{min_price: nil, max_price: nil, alternate_price: nil, door_price: 2000, advance_price: 1000, sold_out: false}
    iex> Showtimes.Processor.process_price("$10 (or clothing donation)")
    %{min_price: 1000, max_price: nil, alternate_price: "(or clothing donation)", door_price: nil, advance_price: nil, sold_out: false}
    iex> Showtimes.Processor.process_price("$SOLD OUT")
    %{min_price: nil, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: true}
    iex> Showtimes.Processor.process_price("$FREE")
    %{min_price: nil, max_price: nil, alternate_price: nil, door_price: nil, advance_price: nil, sold_out: false}
  """

  @price_defaults %{
    min_price: nil,
    max_price: nil,
    alternate_price: nil,
    advance_price: nil,
    door_price: nil,
    sold_out: false
  }
  def process_price(price) do
    case price do
      <<"$", min_price::binary-size(1)>> ->
        Map.merge(@price_defaults, %{min_price: String.to_integer(min_price) * 100})

      <<"$", min_price::binary-size(2)>> ->
        Map.merge(@price_defaults, %{min_price: String.to_integer(min_price) * 100})

      <<"$", min_price::binary-size(1), "-$", max_price::binary>> ->
        Map.merge(@price_defaults, %{
          min_price: String.to_integer(min_price) * 100,
          max_price: String.to_integer(max_price) * 100
        })

      <<"$", min_price::binary-size(2), "-$", max_price::binary>> ->
        Map.merge(@price_defaults, %{
          min_price: String.to_integer(min_price) * 100,
          max_price: String.to_integer(max_price) * 100
        })

      <<"$", advance_price::binary-size(1), " adv/$", door_price::binary-size(1), " doors">> ->
        Map.merge(@price_defaults, %{
          door_price: String.to_integer(door_price) * 100,
          advance_price: String.to_integer(advance_price) * 100
        })

      <<"$", advance_price::binary-size(1), " adv/$", door_price::binary-size(2), " doors">> ->
        Map.merge(@price_defaults, %{
          door_price: String.to_integer(door_price) * 100,
          advance_price: String.to_integer(advance_price) * 100
        })

      <<"$", advance_price::binary-size(2), " adv/$", door_price::binary-size(2), " doors">> ->
        Map.merge(@price_defaults, %{
          door_price: String.to_integer(door_price) * 100,
          advance_price: String.to_integer(advance_price) * 100
        })

      <<"$", min_price::binary-size(1), " ", alternate_price::binary>> ->
        Map.merge(@price_defaults, %{
          min_price: String.to_integer(min_price) * 100,
          alternate_price: alternate_price
        })

      <<"$", min_price::binary-size(2), " ", alternate_price::binary>> ->
        Map.merge(@price_defaults, %{
          min_price: String.to_integer(min_price) * 100,
          alternate_price: alternate_price
        })

      "$SOLD OUT" ->
        Map.merge(@price_defaults, %{sold_out: true})

      _ ->
        @price_defaults
    end
  end

  @doc """
  ## Examples
    iex> Showtimes.Processor.process_time("9AM", ~D[2025-02-01])
    %{start_times: [DateTime.new!(~D[2025-02-01], ~T[09:00:00], "America/New_York")], duration: nil}

    iex> Showtimes.Processor.process_time("9AM-12PM", ~D[2025-02-01])
    %{start_times: [DateTime.new!(~D[2025-02-01], ~T[09:00:00], "America/New_York")], duration: 10800}

    iex> Showtimes.Processor.process_time("7:30PM & 9PM", ~D[2025-02-01])
    %{start_times: [DateTime.new!(~D[2025-02-01], ~T[19:30:00], "America/New_York"), DateTime.new!(~D[2025-02-01], ~T[21:00:00], "America/New_York")], duration: nil}
  """
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
    #DateTime<2025-02-01 09:00:00-05:00 EST America/New_York>

    iex> Showtimes.Processor.do_process_time("9:30AM", ~D[2025-02-01])
    #DateTime<2025-02-01 09:30:00-05:00 EST America/New_York>

    iex> Showtimes.Processor.do_process_time("5:30PM", ~D[2025-02-01])
    #DateTime<2025-02-01 17:30:00-05:00 EST America/New_York>

    iex> Showtimes.Processor.do_process_time("12:30PM", ~D[2025-02-01])
    #DateTime<2025-02-01 12:30:00-05:00 EST America/New_York>
  """
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
        DateTime.new!(date, t, "America/New_York")

      <<hour::binary-size(2), meridian::binary-size(2)>> ->
        hour = String.to_integer(hour)

        hour =
          if meridian == "PM" && hour < 12 do
            hour + 12
          else
            hour
          end

        t = Time.new!(hour, 0, 0)
        DateTime.new!(date, t, "America/New_York")

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
        DateTime.new!(date, t, "America/New_York")

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
        DateTime.new!(date, t, "America/New_York")
    end
  end
end
