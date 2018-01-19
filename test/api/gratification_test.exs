defmodule Paytm.API.GratificationTest do
  use   Paytm.DataCase
  alias Paytm.Support.Helpers
  alias Paytm.API.Gratification
  alias Gratification.Transaction

  setup_all do
    ExVCR.Config.filter_sensitive_data(~s("merchantGuid":".*?"), ~s("merchantGuid":"MERCHANT_GUID"))
    ExVCR.Config.filter_sensitive_data(~s("salesWalletGuid":".*?"), ~s("salesWalletGuid":"SALES_WALLET_GUID"))
    ExVCR.Config.filter_sensitive_data(~s("merchantOrderId":".*?"), ~s("merchantOrderId":"foobar"))
    ExVCR.Config.filter_sensitive_data(~s("txnId":".*?"), ~s("txnId":"TXN_ID"))
    ExVCR.Config.filter_sensitive_data(~s("payeePhoneNumber":".*?"), ~s("payeePhoneNumber":"9999999999"))
    ExVCR.Config.filter_sensitive_data(~s("payeeEmailId":".*?"), ~s("payeeEmailId":"foo@bar.com"))
    ExVCR.Config.filter_request_headers("mid")
    ExVCR.Config.filter_request_headers("checksumhash")

    :ok
  end

  @email             "foo@barbaz.com"
  @existing_user     "7777777777"

  describe "credit/5" do
    @tag :pending
    test "successfully credits an existing user's wallet" do
      use_cassette "api-gratification-credit-successful-credit", match_requests_on: [:request_body] do
        assert {:ok, _response, :success} = Gratification.credit(Money.new(10_00, :INR), Helpers.random_id(), @existing_user, @email)
      end
    end

    @tag :pending
    test "returns :error on invalid data" do
      use_cassette "api-gratification-credit-unsuccessful-credit", match_requests_on: [:request_body] do
        assert {:error, _, "GE_1011"} =
          Gratification.credit(Money.new(10_00, :INR), Helpers.random_id(), "not_a_phone_number", "invalid_email_foo_bar")
      end
    end

    test "doesn't normally allow crediting of a new user" do
      use_cassette "api-gratification-credit-unsuccessful-new-user-credit", match_requests_on: [:request_body] do
        assert {:error, _, "STUC_1002"} =
          Gratification.credit(Money.new(10_00, :INR), Helpers.random_id(), Helpers.random_phone(), "#{Helpers.random_id()}@foobar.com")
      end
    end

    test "allows crediting of a new user when apply_to_new_users is true" do
      use_cassette "api-gratification-credit-successful-new-user-credit", match_requests_on: [:request_body] do
        assert {:ok, _response, :pending} =
          Gratification.credit(Money.new(10_00, :INR), Helpers.random_id(), Helpers.random_phone(), "#{Helpers.random_id()}@foobar.com", apply_to_new_users: true)
      end
    end
  end

  describe "check_status/2" do
    test "returns details about an actual transaction" do
      use_cassette "api-gratification-successful-check-status", match_requests_on: [:request_body] do
        order_id = Helpers.random_id()
        assert {:ok, _response, :pending} =
          Gratification.credit(Money.new(10_00, :INR), order_id, Helpers.random_phone(), "#{Helpers.random_id()}@foobar.com", apply_to_new_users: true)
        assert {:ok, [%Transaction{id: id, status: :pending}]} = Gratification.check_status(:order_id, order_id)
        assert id
      end
    end

    test "returns an error for invalid transactions" do
      use_cassette "api-gratification-unsuccessful-check-status", match_requests_on: [:request_body] do
        assert {:error, "Invalid transaction id.", "GE_1009"} = Gratification.check_status(:order_id, Helpers.random_id())
      end
    end
  end

end
