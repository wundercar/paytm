defmodule Paytm.API.Wallet do
  alias Paytm.Checksum
  alias Paytm.API.OAuth.Token
  alias Paytm.API.Wallet.{Balance, Transaction}

  @error_codes %{
    "403" => :unauthorized_access,
    "404" => :user_not_found,
    "408" => :request_timed_out,
    "500" => :internal_server_error,
    "AM_1001" => :unknown_error,
    "GE_0001" => :unknown_error,
    "CBM_1001" => :incorrect_merchant_details,
    "CBM_1002" => :incorrect_payee_details,
  }

  @paytm_error_regex ~r/(?<code>\d{1,4})=(?<message>.*),?/

  @spec fetch_balance(token :: Token.t | String.t)
        :: {:ok, balance :: Balance.t}
        |  {:error, message :: String.t | atom, code :: atom | nil}
  def fetch_balance(token) when is_binary(token) and token != "" do
    fetch_balance(%Token{access_token: token})
  end
  def fetch_balance(%Token{access_token: access_token}) do
    config(:check_balance_url)
    |> HTTPoison.get([{"content-type", "application/json"}, {"ssotoken", access_token}], [recv_timeout: config(:recv_timeout)])
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
      {:ok, %{"status" => "FAILURE",
              "statusCode" => code,
              "statusMessage" => message}} ->
        {:error, message, @error_codes[code] || code}
      {:error, message, code} -> {:error, message, code}
      _ -> {:error, "An unknown error occurred", nil}
    end
  end

  @spec add_money(
          money :: Money.t,
          order_id :: String.t,
          customer_id :: String.t,
          token :: Token.t | String.t,
          options :: [channel: String.t | nil, callback_url: String.t | nil]
        ) :: {:ok, params :: map} | {:error, message :: String.t, code :: nil}
  def add_money(money, order_id, customer_id, token, options \\ [])
  def add_money(money, order_id, customer_id, token, options) when is_binary(token) and token != "" do
    add_money(money, order_id, customer_id, %Token{access_token: token}, options)
  end
  def add_money(%Money{amount: amount, currency: :INR}, order_id, customer_id, %Token{access_token: token}, options) do
    params = %{
      MID: config(:merchant_id),
      CALLBACK_URL: options[:callback_url] || config(:callback_url),
      REQUEST_TYPE: "ADD_MONEY",
      ORDER_ID: order_id,
      CUST_ID: customer_id,
      TXN_AMOUNT: amount_to_decimal_string(amount),
      CHANNEL_ID: options[:channel] || config(:default_channel),
      INDUSTRY_TYPE_ID: config(:merchant_industry),
      WEBSITE: config(:merchant_website),
      SSO_TOKEN: token
    }

    {:ok, Map.put(params, :CHECKSUMHASH, Checksum.generate(params))}
  end

  @spec charge(
          money :: Money.t,
          order_id :: String.t,
          customer_id :: String.t,
          token :: Token.t | String.t,
          options :: [channel: String.t | nil, app_ip: String.t | nil]
        ) :: {:ok, transaction :: Transaction.t} |
             {:error, message :: String.t, code :: String.t | atom | nil, transaction :: Transaction.t | nil}
  def charge(%Money{amount: amount, currency: :INR}, order_id, customer_id, %Token{access_token: token, phone: phone}, options \\ []) do
    params = %{
      MID: config(:merchant_id),
      ReqType: "WITHDRAW",
      TxnAmount: amount_to_decimal_string(amount),
      AppIP: options[:app_ip] || "127.0.0.1",
      OrderId: order_id,
      Currency: "INR",
      DeviceId: phone,
      SSOToken: token,
      PaymentMode: "PPI",
      CustId: customer_id,
      IndustryType: config(:merchant_industry),
      Channel: options[:channel] || config(:default_channel),
      AuthMode: "USRPWD"
    }

    body =
      params
      |> Map.put(:CheckSum, Checksum.generate(params))
      |> paytm_json_encode

    "/oltp/HANDLER_FF/withdrawScw"
    |> add_base_url
    |> HTTPoison.post(body, [], [recv_timeout: config(:recv_timeout)])
    |> handle_response
    |> case do
      {:ok, %{"Error" => error}} ->
        if Regex.match?(@paytm_error_regex, error) do
          extracted = Regex.named_captures(@paytm_error_regex, error)
          {:error, extracted["message"], extracted["code"], nil}
        else
          {:error, error, nil, nil}
        end
      {:ok, body} ->
        transaction = %Transaction{
          id: body["TxnId"],
          merchant_id: body["MID"],
          merchant_uid: body["MBID"],
          order_id: body["OrderId"],
          customer_id: body["CustId"],
          money: Money.new(paytm_amount_to_cents(body["TxnAmount"]), :INR),
          successful: body["Status"] == "TXN_SUCCESS",
          payment_mode: body["PaymentMode"],
          bank_name: body["BankName"],
          bank_transaction_id: body["BankTxnId"],
        }
        if transaction.successful do
          {:ok, transaction}
        else
          {:error, body["ResponseMessage"], body["ResponseCode"], transaction}
        end
      {:error, message, code} -> {:error, message, code, nil}
      _ -> {:error, "An unknown error occurred", nil, nil}
    end
  end

  @spec refund(transaction :: Transaction.t, reference :: String.t, refund_money :: Money.t | nil)
        :: {:ok, refund_id :: String.t} |
           {:error, message :: String.t, code :: String.t}
  def refund(transaction, reference, amount \\ nil)
  def refund(%Transaction{money: %Money{currency: currency}}, _, _)
  when currency != :INR do
    {:error, "Only INR is supported for Paytm refunds", nil}
  end
  def refund(%Transaction{money: %Money{currency: currency}}, _, %Money{currency: refund_currency})
  when refund_currency != currency do
    {:error, "Can only refund the same currency", nil}
  end
  def refund(%Transaction{money: %Money{amount: amount}}, _, %Money{amount: refund_amount})
  when refund_amount > amount do
    {:error, "Cannot refund more than the transaction value", nil}
  end
  def refund(transaction, reference, refund_money) do
    params = %{
      ORDERID: transaction.order_id,
      REFUNDAMOUNT: amount_to_decimal_string(refund_money || transaction.money),
      TXNID: transaction.id,
      MID: transaction.merchant_id,
      TXNTYPE: "REFUND",
      REFID: reference,
    }

    body =
      params
      |> Map.put(:CHECKSUM, Checksum.generate(params))
      |> paytm_json_encode

    "/oltp/HANDLER_INTERNAL/REFUND"
    |> add_base_url
    |> HTTPoison.post(body, [], [recv_timeout: config(:recv_timeout)])
    |> handle_response
    |> case do
      {:ok, %{"STATUS" => "TXN_SUCCESS"} = body} ->
        {:ok, body["REFUNDID"]}
      {:ok, %{"STATUS" => "TXN_FAILURE"} = body} ->
        {:error, body["RESPMSG"], body["RESPCODE"]}
      {:error, message, code} ->
        {:error, message, code}
      _ ->
        {:error, "An unknown error occurred", nil}
    end
  end

  @spec check_status(order_id :: String.t)
        :: {:ok, transaction :: Transaction.t} |
           {:error, message :: String.t, code :: String.t}
  def check_status(order_id) do
    params = %{
      MID: config(:merchant_id),
      ORDERID: order_id,
    }

    body =
      params
      |> Map.put(:CHECKSUMHASH, Checksum.generate(params))
      |> paytm_json_encode

    "/oltp/HANDLER_INTERNAL/getTxnStatus"
    |> add_base_url
    |> HTTPoison.post(body, [], [recv_timeout: config(:recv_timeout)])
    |> handle_response
    |> case do
      {:ok, %{"TXNID" => txn_id} = body} when txn_id != "" ->
        {:ok, %Transaction{
          id: body["TXNID"],
          merchant_id: body["MID"],
          merchant_uid: body["MBID"],
          order_id: body["ORDERID"],
          customer_id: body["CustId"],
          money: Money.new(paytm_amount_to_cents(body["TXNAMOUNT"]), :INR),
          refunded_money: Money.new(paytm_amount_to_cents(body["REFUNDAMT"]), :INR),
          successful: body["STATUS"] == "TXN_SUCCESS",
          gateway_name: body["GATEWAYNAME"],
          payment_mode: body["PAYMENTMODE"],
          bank_name: body["BANKNAME"],
          bank_transaction_id: body["BANKTXNID"],
          response_code: body["RESPCODE"],
          response_message: body["RESPMSG"],
          timestamp: paytm_timestamp(body["TXNDATE"]),
        }}
      {:ok, %{"ErrorCode" => code, "ErrorMsg" => message}} ->
        {:error, message, code}
      {:ok, %{"RESPCODE" => code, "RESPMSG" => message}} ->
        {:error, message, code}
      {:error, message, code} ->
        {:error, message, code}
      _ ->
        {:error, "An unknown error occurred", nil}
    end
  end

  defp config(key) when is_atom(key) do
    Application.get_env(:paytm, Paytm.API.Wallet)[key]
  end

  defp add_base_url(url) do
    config(:base_url)
    |> URI.merge(url)
    |> URI.to_string
  end

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

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, "", reason}
  defp handle_response({:ok, %HTTPoison.Response{body: ""}}), do: {:error, "Invalid response from Paytm", nil}
  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    body
    |> Poison.decode!
    |> handle_body
  end
  defp handle_response(_), do: {:error, "An unknown error occurred", nil}

  defp handle_body(%{} = body), do: {:ok, body}

  defp paytm_amount_to_cents(nil), do: 0
  defp paytm_amount_to_cents(""), do: 0
  defp paytm_amount_to_cents(string) when is_binary(string) do
    string
    |> String.to_float
    |> paytm_amount_to_cents
  end
  defp paytm_amount_to_cents(float) when is_float(float) do
    trunc(float * 100)
  end

  defp paytm_timestamp(""), do: nil
  defp paytm_timestamp(nil), do: nil
  defp paytm_timestamp(string) do
    with {:ok, naive_date_time}      <- Timex.parse(string, "{ISOdate} {ISOtime}"),
         %DateTime{} = date_time     <- Timex.to_datetime(naive_date_time, "+05:30"),
         %DateTime{} = utc_date_time <- Timex.to_datetime(date_time)
    do
      utc_date_time
    else
      _ -> nil
    end
  end
end
