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
      {:error, message, code} -> {:error, message, code}
      _ -> {:error, "An unknown error occurred", nil}
    end
  end

  @spec add_money(
          money :: Money.t,
          order_id :: String.t,
          customer_id :: String.t,
          token :: Token.t | String.t,
          options :: [channel_id: String.t]
        ) :: {:ok, params :: map} | {:error, message :: String.t, code :: nil}
  def add_money(money, order_id, customer_id, token) when is_binary(token) and token != "" do
    add_money(money, order_id, customer_id, %Token{access_token: token})
  end
  def add_money(%Money{amount: amount, currency: :INR}, order_id, customer_id, %Token{access_token: token}, options \\ []) do
    params = %{
      MID: config(:merchant_id),
      CALLBACK_URL: config(:callback_url),
      REQUEST_TYPE: "ADD_MONEY",
      ORDER_ID: order_id,
      CUST_ID: customer_id,
      TXN_AMOUNT: amount_to_decimal_string(amount),
      CHANNEL_ID: options[:channel] || config(:default_channel),
      INDUSTRY_TYPE_ID: config(:merchant_industry),
      WEBSITE: config(:merchant_website),
      SSO_TOKEN: token
    }

    {:ok, Map.put(params, :CHECKSUMHASH, Checksum.generate(params, false))}
  end

  @spec charge(
          money :: Money.t,
          order_id :: String.t,
          customer_id :: String.t,
          token :: Token.t | String.t,
          options :: [channel_id: String.t, app_ip: String.t]
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
    "JsonData=" <> Poison.encode!(map)
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

  defp handle_body(%{"status" => "FAILURE", "statusCode" => code, "statusMessage" => message}) do
    {:error, message, @error_codes[code] || code}
  end
  defp handle_body(%{"ResponseCode" => code, "ResponseMessage" => message, "Status" => status} = response) do
    transaction = extract_transaction_from_withdrawal_response(response)
    if status == "TXN_SUCCESS" do
      {:ok, transaction}
    else
      {:error, message, code, transaction}
    end
  end
  defp handle_body(%{"Error" => error}) do
    if Regex.match?(@paytm_error_regex, error) do
      extracted = Regex.named_captures(@paytm_error_regex, error)
      {:error, extracted["message"], extracted["code"], nil}
    else
      {:error, error, nil, nil}
    end
  end
  defp handle_body(%{} = body), do: {:ok, body}

  def extract_transaction_from_withdrawal_response(response) do
    %Transaction{
      id: response["TxnId"],
      merchant_id: response["MID"],
      merchant_uid: response["MBID"],
      order_id: response["OrderId"],
      customer_id: response["CustId"],
      money: Money.new(paytm_amount_to_cents(response["TxnAmount"]), :INR),
      successful: response["Status"] == "TXN_SUCCESS",
      payment_mode: response["PaymentMode"],
      bank_name: response["BankName"],
      bank_transaction_id: response["BankTxnId"],
    }
  end

  def paytm_amount_to_cents(string) when is_binary(string) do
    string
    |> String.to_float
    |> paytm_amount_to_cents
  end
  def paytm_amount_to_cents(float) when is_float(float) do
    trunc(float * 100)
  end
end
