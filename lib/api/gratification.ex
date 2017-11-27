defmodule Paytm.API.Gratification do
  alias Paytm.Checksum

  @error_codes %{}

  @spec credit(
    money :: Money.t,
    order_id :: String.t,
    phone :: String.t,
    email :: String.t,
    options :: [
      sales_wallet_name: String.t | nil,
      sales_wallet_guid: String.t | nil,
      apply_to_new_users: boolean | nil,
      metadata: String.t | nil,
      ip_address: String.t | nil,
    ]
  ) :: {:ok, transaction_id :: String.t, status :: :success | :pending}
    |  {:error, message :: String.t, code :: atom | String.t}
  def credit(%Money{amount: amount, currency: :INR}, order_id, phone, email, options \\ []) do
    params = %{
      request: %{
        requestType: "",
        merchantGuid: config(:merchant_guid),
        merchantOrderId: order_id,
        salesWalletName: options[:sales_wallet_name] || config(:default_sales_wallet_name),
        salesWalletGuid: options[:sales_wallet_guid] || config(:default_sales_wallet_guid),
        payeeEmailId: email,
        payeePhoneNumber: phone,
        payeeSsoId: "",
        appliedToNewUsers: (if options[:apply_to_new_users], do: "Y", else: "N"),
        amount: amount_to_decimal_string(amount),
        currencyCode: "INR",
      },
      metadata: options[:metadata],
      ipAddress: options[:ip_address] || "127.0.0.1",
      platformName: "PayTM",
      operationType: "SALES_TO_USER_CREDIT",
    }

    body = Poison.encode!(params)

    headers = [
      {"content-type", "application/json"},
      {"mid", config(:merchant_guid)},
      {"checksumhash", Checksum.generate(body, Paytm.API.Gratification)}
    ]

     "/wallet-web/salesToUserCredit"
     |> add_base_url
     |> HTTPoison.post(body, headers, [recv_timeout: config(:recv_timeout)])
     |> handle_response
     |> case do
       {:ok, %{"status" => "SUCCESS",
               "statusCode" => "SUCCESS",
               "statusMessage" => "SUCCESS",
               "response" => %{
                 "walletSysTransactionId" => transaction_id
               }}} ->
         {:ok, transaction_id, :success}
       {:ok, %{"status" => "PENDING",
               "statusCode" => code,
               "statusMessage" => message,
               "response" => %{
                 "walletSysTransactionId" => transaction_id
               }}} ->
         {:ok, transaction_id, :pending}
       {:ok, %{"status" => "FAILURE",
               "statusCode" => code,
               "statusMessage" => message}} ->
         {:error, message, @error_codes[code] || code}
     end
  end

  defp config(key) when is_atom(key) do
    Application.get_env(:paytm, Paytm.API.Gratification)[key]
  end

  defp add_base_url(url) do
    config(:base_url)
    |> URI.merge(url)
    |> URI.to_string
  end

  defp amount_to_decimal_string(%Money{amount: amount_cents}) do
    amount_to_decimal_string(amount_cents)
  end
  defp amount_to_decimal_string(amount_cents) do
    :erlang.float_to_binary(amount_cents / 100, decimals: 2)
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, "", reason}
  defp handle_response({:ok, %HTTPoison.Response{body: ""}}), do: {:ok, %{}}
  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    body
    |> Poison.decode!
    |> handle_body
  end
  defp handle_response(_), do: {:error, "An unknown error occurred", nil}

  defp handle_body(%{} = body), do: {:ok, body}
end
