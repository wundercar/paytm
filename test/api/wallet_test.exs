defmodule Paytm.API.WalletTest do
  use Paytm.DataCase
  alias Paytm.Support.Helpers
  alias Paytm.API.{OAuth, Wallet}
  alias OAuth.Token
  alias Wallet.{Balance, Transaction}

  setup do
    ExVCR.Config.filter_sensitive_data(~s("clientId":".*?"), ~s("clientId":"CLIENT_ID"))
    ExVCR.Config.filter_sensitive_data(~s("MID":".*?"), ~s("MID":"MID"))
    ExVCR.Config.filter_sensitive_data(~s("MBID":".*?"), ~s("MBID":"MBID"))
    ExVCR.Config.filter_sensitive_data(~s("OrderId":".*?"), ~s("OrderId":"abc123"))
    ExVCR.Config.filter_sensitive_data(~s("CustId":".*?"), ~s("CustId":"abc123"))
    ExVCR.Config.filter_sensitive_data(~s("SSOToken":".*?"), ~s("SSOToken":"SSO_TOKEN"))
    ExVCR.Config.filter_sensitive_data(~s("CheckSum":".*?"), ~s("CheckSum":"CHECKSUM"))
    ExVCR.Config.filter_sensitive_data(~s("CHECKSUMHASH":".*?"), ~s("CHECKSUMHASH":"CHECKSUM"))
    ExVCR.Config.filter_sensitive_data(~s("ORDERID":".*?"), ~s("ORDERID":"abc123"))

    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_headers("Set-Cookie")
    ExVCR.Config.filter_request_headers("ssotoken")

    :ok
  end

  @email "bar@baz.com"
  @existing_user "7777777777"
  @existing_user_otp "489871"

  describe "fetch_balance/1" do
    test "fetches balance successfully with a valid token" do
      use_cassette "api-wallet-fetch_balance-valid-token", match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:ok, %Token{} = token} = OAuth.validate_otp(@existing_user_otp, state)
        assert {:ok, %Balance{} = balance} = Wallet.fetch_balance(token)

        assert balance.total_balance.currency == :INR
        assert balance.paytm_wallet_balance.currency == :INR
        assert balance.sub_wallet_balance.currency == :INR

        assert balance.total_balance.amount > 0
        assert balance.paytm_wallet_balance.amount > 0

        assert Money.subtract(balance.total_balance, balance.paytm_wallet_balance) ==
                 balance.sub_wallet_balance
      end
    end

    test "returns :unauthorized_access for an invalid token" do
      use_cassette "api-wallet-fetch_balance-invalid-token", match_requests_on: [:request_body] do
        assert {:error, _, :unauthorized_access} = Wallet.fetch_balance("foo")
      end
    end
  end

  @default_options [channel: "WEB", app_ip: "127.0.0.1"]

  describe "charge/5" do
    test "successfully adds money and returns a transaction when there is sufficient balance" do
      use_cassette "api-wallet-charge-success", match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:ok, %Token{} = token} = OAuth.validate_otp(@existing_user_otp, state)
        assert {:ok, %Token{} = token} = OAuth.validate_token(token)

        assert {:ok, %Transaction{successful: true}} =
                 Wallet.charge(
                   Money.new(1_00, :INR),
                   Helpers.random_id(),
                   Helpers.random_id(),
                   token,
                   @default_options
                 )
      end
    end

    test "returns an error when balance isn't sufficient" do
      use_cassette "api-wallet-charge-insufficient_balance", match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:ok, %Token{} = token} = OAuth.validate_otp(@existing_user_otp, state)
        assert {:ok, %Token{} = token} = OAuth.validate_token(token)
        assert {:ok, %Balance{} = balance} = Wallet.fetch_balance(token)

        assert {:error, _message, "235", %Transaction{successful: false}} =
                 Wallet.charge(
                   Money.add(balance.paytm_wallet_balance, Money.new(1000_00, :INR)),
                   Helpers.random_id(),
                   Helpers.random_id(),
                   token,
                   @default_options
                 )
      end
    end
  end

  describe "add_money/5" do
    test "returns a valid map" do
      token = %Token{access_token: "foo"}

      assert {:ok, %{REQUEST_TYPE: "ADD_MONEY"}} =
               Wallet.add_money(
                 Money.new(1_00, :INR),
                 Helpers.random_id(),
                 Helpers.random_id(),
                 token,
                 @default_options
               )
    end
  end

  describe "refund/2" do
    @tag :pending
    test "successfully refunds transactions" do
      use_cassette "api-wallet-refund-success", match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:ok, %Token{} = token} = OAuth.validate_otp(@existing_user_otp, state)
        assert {:ok, %Token{} = token} = OAuth.validate_token(token)

        assert {:ok, %Balance{} = balance_before} = Wallet.fetch_balance(token)

        assert {:ok, %Transaction{successful: true} = transaction} =
                 Wallet.charge(
                   Money.new(1_00, :INR),
                   Helpers.random_id(),
                   Helpers.random_id(),
                   token,
                   @default_options
                 )

        assert {:ok, _refund_id} = Wallet.refund(transaction, Helpers.random_id())

        assert {:ok, %Balance{} = balance_after} = Wallet.fetch_balance(token)

        assert Money.equal?(balance_before, balance_after)
      end
    end
  end

  describe "check_status/1" do
    test "returns transaction details" do
      use_cassette "api-wallet-charge-success-transaction-details",
        match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:ok, %Token{} = token} = OAuth.validate_otp(@existing_user_otp, state)
        assert {:ok, %Token{} = token} = OAuth.validate_token(token)
        order_id = "60339ae8-d5c5-4937-94a6-ad568081088e"

        assert {:ok, %Transaction{successful: true}} =
                 Wallet.charge(
                   Money.new(1_00, :INR),
                   order_id,
                   Helpers.random_id(),
                   token,
                   @default_options
                 )

        assert {:ok, %Transaction{successful: true, timestamp: %DateTime{}}} =
                 Wallet.check_status(order_id)
      end
    end
  end
end
