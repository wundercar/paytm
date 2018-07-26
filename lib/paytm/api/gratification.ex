defmodule Paytm.API.Gratification do
  use Paytm.API.Base
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
     |> HTTPoison.post(body, headers, httpoison_options())
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
     |> HTTPoison.post(body, headers, httpoison_options())
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
end
