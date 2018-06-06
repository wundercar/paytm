defmodule Paytm.API.Gratification do
  alias Paytm.Checksum
  alias Paytm.API.Gratification.Transaction

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
  ) :: {:ok, response :: map, status :: :success | :pending}
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
     |> HTTPoison.post(body, headers, [recv_timeout: config(:recv_timeout), hackney: [:insecure]])
     |> handle_response
     |> case do
       {:ok, %{"status" => "SUCCESS",
               "statusCode" => "SUCCESS",
               "statusMessage" => "SUCCESS",
               "response" => response}} ->
         {:ok, response, :success}
       {:ok, %{"status" => "PENDING",
               "statusCode" => _,
               "statusMessage" => _,
               "response" => response}} ->
         {:ok, response, :pending}
       {:ok, %{"statusCode" => code,
               "statusMessage" => message}} ->
         {:error, message, @error_codes[code] || code}
       {:error, message, code} ->
         {:error, message, code}
        _ ->
          {:error, "An unknown error occurred", nil}
     end
  end

  @reference_types %{
    order_id: "merchanttxnid",
    transaction_id: "wallettxnid",
    refund_id: "wallettxnid",
  }
  @spec check_status(
    reference_type :: :order_id | :transaction_id | :refund_id,
    reference :: String.t
    ) :: {:ok, transactions :: [Transaction.t]}
    |  {:error, message :: String.t, code :: atom | String.t}
  def check_status(reference_type, reference) do
    params = %{
      request: %{
        requestType: @reference_types[reference_type],
        txnType: "salestouser",
        txnId: reference,
        merchantGuid: config(:merchant_guid),
      },
      platformName: "PayTM",
      operationType: "CHECK_TXN_STATUS",
    }

    body = Poison.encode!(params)

    headers = [
      {"content-type", "application/json"},
      {"mid", config(:merchant_guid)},
      {"checksumhash", Checksum.generate(body, Paytm.API.Gratification)}
    ]

     "/wallet-web/checkStatus"
     |> add_base_url
     |> HTTPoison.post(body, headers, [recv_timeout: config(:recv_timeout), hackney: [:insecure]])
     |> handle_response
     |> case do
       {:ok, %{"status" => "SUCCESS",
               "statusMessage" => "SUCCESS",
               "response" => response}} ->
         {:ok, Enum.map(response["txnList"], &extract_transaction/1)}
       {:ok, %{"status" => "FAILURE",
               "statusCode" => code,
               "statusMessage" => message}} ->
         {:error, message, @error_codes[code] || code}
       {:error, message, code} ->
         {:error, message, code}
        _ ->
          {:error, "An unknown error occurred", nil}
     end
  end

  @status_atoms %{
    0 => :init,
    1 => :success,
    2 => :failure,
    3 => :pending,
  }

  defp extract_transaction(transaction) do
    %Transaction{
      id: transaction["txnGuid"],
      order_id: transaction["merchantOrderId"],
      money: Money.new(paytm_amount_to_cents(transaction["txnAmount"]), :INR),
      status: @status_atoms[transaction["status"]],
    }
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

  defp paytm_amount_to_cents(string) when is_binary(string) do
    string
    |> String.to_float
    |> paytm_amount_to_cents
  end
  defp paytm_amount_to_cents(float) when is_float(float) do
    trunc(float * 100)
  end
  defp paytm_amount_to_cents(integer) when is_integer(integer) do
    integer * 100
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, "", reason}
  defp handle_response({:ok, %HTTPoison.Response{body: ""}}), do: {:error, "Invalid response from Paytm", nil}
  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    case Poison.decode(body) do
      {:ok, decoded_body} -> handle_body(decoded_body)
      _ -> {:error, "Invalid response from Paytm", nil}
    end
  end
  defp handle_response(_), do: {:error, "An unknown error occurred", nil}

  defp handle_body(%{} = body), do: {:ok, body}
end
