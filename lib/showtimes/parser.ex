defmodule Showtimes.Parser do
  @doc """
  Parses strings of the form {performers}. {time}, {price} @ {location}", extracting the named terms.

  ## Examples
    iex> Showtimes.Parser.parse_event("Thonian Horde, The Edge Of Desolation, Chiaroscuro, Revvnant. 7PM, $15 @ Ottobar")
    %{performers: "Thonian Horde, The Edge Of Desolation, Chiaroscuro, Revvnant", time: "7PM", price: "$15", location: "Ottobar"}

    iex> Showtimes.Parser.parse_event("Contact Mic: Open Experimental Jam Series - 7:30PM, $FREE @ Wax Atlas")
    %{performers: "Contact Mic: Open Experimental Jam Series", time: "7:30PM", price: "$FREE", location: "Wax Atlas"}
  """
  def parse_event(s) do
    s = String.trim(s)

    if String.length(s) == 0 do
      nil
    else
      with {performers, rest} <-
             parse_until(
               parse_or([
                 parse_and([parse_string(". "), Showtimes.Parser.parse_number()]),
                 parse_and([parse_string(" - "), Showtimes.Parser.parse_number()])
               ]),
               s
             ),
           {_, rest} <- parse_or([parse_string(". "), parse_string(" - ")], rest),
           {time, rest} <- parse_time(rest),
           {_, rest} <- parse_string(", ", rest),
           {price, rest} <- parse_price(rest),
           {_, rest} <- parse_string(" @ ", rest),
           {location, ""} <- parse_any(rest) do
        %{performers: performers, time: time, price: price, location: location}
      end
    end
  end

  @doc """
  Parses a string until a certain pattern is matched, and returns the substring preceding the match
  and the rest of the search string. If the pattern is never matched, returns tuple of nil and the search string.

  ## Examples

    iex> Showtimes.Parser.parse_until(Showtimes.Parser.parse_and([Showtimes.Parser.parse_string(". "), Showtimes.Parser.parse_number]), "foobar. 8PM")
    {"foobar", ". 8PM"}

    iex> Showtimes.Parser.parse_until(Showtimes.Parser.parse_string("blub"), "foobar. 8PM")
    {:error, "foobar. 8PM"}
  """
  def parse_until(parser_fn, s, index \\ 0)
  def parse_until(_, s, index) when index > byte_size(s) - 1, do: {:error, s}

  def parse_until(parser_fn, s, index) do
    substring = String.slice(s, index..-1//1)

    case parser_fn.(substring) do
      {:error, ^substring} -> parse_until(parser_fn, s, index + 1)
      _ -> String.split_at(s, index)
    end
  end

  def parse_string(substring) do
    &parse_string(substring, &1)
  end

  @doc """
  Searches for a substring in a search string. If found, returns a tuple of the search string and the rest of the string after it is found.

  ## Examples
    iex> Showtimes.Parser.parse_string("foo", "foobar")
    {"foo", "bar"}

    iex> Showtimes.Parser.parse_string("baz", "foobar")
    {:error, "foobar"}
  """
  def parse_string(substring, s) do
    if String.starts_with?(s, substring) do
      start_index = String.length(substring)
      {substring, String.slice(s, start_index..-1//1)}
    else
      {:error, s}
    end
  end

  def parse_any(s) do
    {s, ""}
  end

  @doc """
  ## Examples
    iex> Showtimes.Parser.parse_time("7PM, $15 @ Ottobar")
    {"7PM", ", $15 @ Ottobar"}

    iex> Showtimes.Parser.parse_time("7:30PM, $10 @ Wax Atlas")
    {"7:30PM", ", $10 @ Wax Atlas"}

    iex> Showtimes.Parser.parse_time("9AM --- gerble")
    {"9AM", " --- gerble"}

    iex> Showtimes.Parser.parse_time("9AM-12PM, $10 @ Red Emma's")
    {"9AM-12PM", ", $10 @ Red Emma's"}

    iex> Showtimes.Parser.parse_time("foobar")
    {:error, "foobar"}
  """
  def parse_time(s) do
    parse_and(
      [
        Showtimes.Parser.do_parse_time(),
        parse_optional(parse_and([parse_string("-"), Showtimes.Parser.do_parse_time()]))
      ],
      s
    )
  end

  def do_parse_time do
    &do_parse_time(&1)
  end

  def do_parse_time(s) do
    parse_and(
      [
        parse_one_or_more(Showtimes.Parser.parse_number()),
        parse_optional(
          parse_and([parse_string(":"), parse_one_or_more(Showtimes.Parser.parse_number())])
        ),
        parse_or([parse_string("AM"), parse_string("PM")])
      ],
      s
    )
  end

  def parse_price(s) do
    parse_and(
      [
        Showtimes.Parser.do_parse_price(),
        parse_optional(parse_and([parse_string("-"), Showtimes.Parser.do_parse_price()]))
      ],
      s
    )
  end

  def do_parse_price do
    &do_parse_price(&1)
  end

  def do_parse_price(s) do
    parse_and(
      [
        parse_string("$"),
        parse_or([
          parse_string("FREE"),
          parse_one_or_more(Showtimes.Parser.parse_number())
        ])
      ],
      s
    )
  end


  def parse_number do
    &parse_number(&1)
  end

  @doc """
  Parses strings that look like numbers.

  ## Examples
    iex> Showtimes.Parser.parse_number("1PM")
    {"1", "PM"}

    iex> Showtimes.Parser.parse_number("12PM")
    {"1", "2PM"}

    iex> Showtimes.Parser.parse_number("foo")
    {:error, "foo"}
  """
  def parse_number(s) do
    c = String.at(s, 0)

    case Integer.parse(c) do
      {_, ""} -> {c, String.slice(s, 1..-1//1)}
      _ -> {:error, s}
    end
  end

  def parse_and(parser_fns) do
    &parse_and(parser_fns, &1)
  end

  @doc """
  Combinator that executes multiple parser functions, all of which must match. Returns a tuple of a string matching the combined functions, and the rest of the string.
  If the parsers don't match, return an error and the original string.

  ## Examples
    iex> Showtimes.Parser.parse_and([Showtimes.Parser.parse_number, Showtimes.Parser.parse_string("PM")], "1PM")
    {"1PM", ""}

    iex> Showtimes.Parser.parse_and([Showtimes.Parser.parse_number, Showtimes.Parser.parse_string(" bananas")], "12 apples")
    {:error, "12 apples"}
  """
  def parse_and(parser_fns, s) do
    Enum.reduce_while(parser_fns, {"", s}, fn parser_fn, {col, r} ->
      case parser_fn.(r) do
        {:error, _} -> {:halt, {:error, s}}
        {m, rest} -> {:cont, {col <> m, rest}}
      end
    end)
  end

  def parse_or(parser_fns) do
    &parse_or(parser_fns, &1)
  end

  @doc """
  ## Examples
    iex> Showtimes.Parser.parse_or([Showtimes.Parser.parse_string("AM"), Showtimes.Parser.parse_string("PM")], "PM")
    {"PM", ""}

    iex> Showtimes.Parser.parse_or([Showtimes.Parser.parse_string("AM"), Showtimes.Parser.parse_string("PM")], "AM on Tuesday")
    {"AM", " on Tuesday"}

    iex> Showtimes.Parser.parse_or([Showtimes.Parser.parse_number, Showtimes.Parser.parse_string("foo")], "bananas")
    {:error, "bananas"}
  """
  def parse_or(parser_fns, s) do
    match =
      parser_fns
      |> Enum.map(fn parser_fn -> parser_fn.(s) end)
      |> Enum.filter(fn result -> result != {:error, s} end)
      |> List.first()

    if is_nil(match) do
      {:error, s}
    else
      match
    end
  end

  def parse_optional(parser_fn) do
    &parse_optional(parser_fn, &1)
  end

  @doc """

  ## Examples
    iex> Showtimes.Parser.parse_optional(Showtimes.Parser.parse_string("foo"), "foobar")
    {"foo", "bar"}

    iex> Showtimes.Parser.parse_optional(Showtimes.Parser.parse_string("foo"), "baz")
    {"", "baz"}
  """
  def parse_optional(parser_fn, s) do
    case parser_fn.(s) do
      {:error, _} -> {"", s}
      {match, rest} -> {match, rest}
    end
  end

  def parse_one_or_more(parser_fn) do
    &parse_one_or_more(parser_fn, &1)
  end

  @doc """
  ## Examples
    iex> Showtimes.Parser.parse_one_or_more(Showtimes.Parser.parse_number, "12")
    {"12", ""}

    iex> Showtimes.Parser.parse_one_or_more(Showtimes.Parser.parse_number, "foo")
    {:error, "foo"}

    iex> Showtimes.Parser.parse_one_or_more(Showtimes.Parser.parse_number, "1foo")
    {"1", "foo"}

  """
  def parse_one_or_more(parser_fn, s, acc \\ "")
  def parse_one_or_more(_parser_fn, "", acc), do: {acc, ""}

  def parse_one_or_more(parser_fn, s, acc) do
    case parser_fn.(s) do
      {:error, s} ->
        if acc == "" do
          {:error, s}
        else
          {acc, s}
        end

      {c, rest} ->
        parse_one_or_more(parser_fn, rest, acc <> c)
    end
  end
end
