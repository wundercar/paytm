defmodule Paytm.API.Wallet do
  use   HTTPoison.Base
  alias Paytm.API.OAuth.Token
  alias Paytm.API.Wallet.Balance

  defp config(key) when is_atom(key) do
    Application.get_env(:paytm, Paytm.API.Wallet)[key]
  end

  defp base_url,          do: config(:base_url)
  defp check_balance_url, do: config(:check_balance_url)

  def process_url(url) do
    base_url() <> url
  end

  @error_codes %{
    "403" => :unauthorized_access,
  }

  @spec fetch_balance(token :: Token.t | String.t)
        :: {:ok, balance :: Balance.t}
        |  {:error, message :: String.t | atom, code :: atom}
  def fetch_balance(token) when is_binary(token) and token != "" do
    fetch_balance(%Token{access_token: token})
  end
  def fetch_balance(%Token{access_token: access_token}) do
    check_balance_url()
    |> HTTPoison.get([{"content-type", "application/json"}, {"ssotoken", access_token}])
    |> handle_response
    |> case do
      {:ok, %{"status" => "SUCCESS",
              "statusCode" => "SUCCESS",
              "statusMessage" => "SUCCESS",
              "response" => %{
                "totalBalance" => total_balance,
                "paytmWalletBalance" => paytm_wallet_balance,
                "otherSubWalletBalance" => sub_wallet_balance,
              }}} ->
        {:ok, Balance.new(:full_units, total_balance, paytm_wallet_balance, sub_wallet_balance)}
      {:error, message, code} -> {:error, message, code}
      _ -> {:error, "An unknown error occurred", nil}
    end
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, "", reason}
  defp handle_response({:ok, %HTTPoison.Response{body: ""}}), do: {:ok, %{}}
  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    body
    |> Poison.decode!
    |> handle_body
  end
  defp handle_response(_), do: {:error, "An unknown error occurred", nil}

  defp handle_body(%{"status" => "FAILURE", "statusCode" => code, "statusMessage" => message}) do
    {:error, message, @error_codes[code] || code}
  end
  defp handle_body(%{} = body), do: {:ok, body}
end
