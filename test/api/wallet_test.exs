defmodule Paytm.API.WalletTest do
  use   Paytm.DataCase
  alias Paytm.API.{OAuth, Wallet}
  alias OAuth.Token
  alias Wallet.Balance

  setup_all do
    ExVCR.Config.filter_sensitive_data(~s("clientId":".*"), ~s("clientId":"CLIENT_ID"))
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_headers("Set-Cookie")
    ExVCR.Config.filter_request_headers("ssotoken")

    :ok
  end

  @email             "bar@baz.com"
  @existing_user     "7777777777"
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
        assert Money.subtract(balance.total_balance, balance.paytm_wallet_balance) == balance.sub_wallet_balance
      end
    end

    test "returns :unauthorized_access for an invalid token" do
      use_cassette "api-wallet-fetch_balance-invalid-token", match_requests_on: [:request_body] do
        assert {:error, _, :unauthorized_access} = Wallet.fetch_balance("foo")
      end
    end
  end
end
