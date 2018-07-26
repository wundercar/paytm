defmodule Paytm.API.Base do
  defmacro __using__(_opts) do
    quote do
      defp config(key) when is_atom(key) do
        Application.get_env(:paytm, __MODULE__)[key]
      end

      defp add_base_url(url) do
        config(:base_url)
        |> URI.merge(url)
        |> URI.to_string()
      end

      defp httpoison_options() do
        [
          recv_timeout: config(:recv_timeout),
          hackney: hackney_options()
        ]
      end

      defp hackney_options() do
        if config(:hackney_insecure) do
          [:insecure]
        else
          []
        end
      end

      defp handle_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, "", reason}

      defp handle_response({:ok, %HTTPoison.Response{body: ""}}),
        do: {:error, "Invalid response from Paytm", nil}

      defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
        case Poison.decode(body) do
          {:ok, decoded_body} -> handle_body(decoded_body)
          _ -> {:error, "Invalid response from Paytm", nil}
        end
      end

      defp handle_response(_), do: {:error, "An unknown error occurred", nil}

      defp handle_body(%{} = body), do: {:ok, body}

      defp paytm_json_encode(map) do
        map_with_uri_encoded_values =
          for {k, v} <- map, into: %{}, do: {k, URI.encode("#{v}", &URI.char_unreserved?(&1))}

        "JsonData=" <> Poison.encode!(map_with_uri_encoded_values)
      end

      defp amount_to_decimal_string(%Money{amount: amount_cents}) do
        amount_to_decimal_string(amount_cents)
      end

      defp amount_to_decimal_string(amount_cents) do
        :erlang.float_to_binary(amount_cents / 100, decimals: 2)
      end

      defp to_integer(integer) when is_integer(integer), do: integer
      defp to_integer(string) when is_binary(string), do: String.to_integer(string)

      defp paytm_amount_to_cents(nil), do: 0
      defp paytm_amount_to_cents(""), do: 0

      defp paytm_amount_to_cents(string) when is_binary(string) do
        string
        |> String.to_float()
        |> paytm_amount_to_cents
      end

      defp paytm_amount_to_cents(float) when is_float(float) do
        trunc(float * 100)
      end

      defp paytm_amount_to_cents(integer) when is_integer(integer) do
        integer * 100
      end

      defp paytm_timestamp(""), do: nil
      defp paytm_timestamp(nil), do: nil

      defp paytm_timestamp(string) do
        with {:ok, naive_date_time} <- Timex.parse(string, "{ISOdate} {ISOtime}"),
             %DateTime{} = date_time <- Timex.to_datetime(naive_date_time, "+05:30"),
             %DateTime{} = utc_date_time <- Timex.to_datetime(date_time) do
          utc_date_time
        else
          _ -> nil
        end
      end
    end
  end
end
