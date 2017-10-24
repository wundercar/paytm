defmodule Paytm.API.OAuthTest do
  use   Paytm.DataCase
  alias Paytm.API.OAuth

  setup_all do
    ExVCR.Config.filter_sensitive_data(~s("clientId":".*"), ~s("clientId":"CLIENT_ID"))
    ExVCR.Config.filter_request_headers("Set-Cookie")

    :ok
  end

  @email         "foo@bar.com"
  @new_user      "9900990099"
  @existing_user "9999999999"

  describe "send_otp/1" do
    test "sends an OTP when correct parameters of an existing user are provided" do
      use_cassette "api-oauth-send_otp-correct-login-params", match_requests_on: [:request_body] do
        assert {:ok, state, :login} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert is_binary(state)
      end
    end

    test "sends an OTP when correct parameters of a new user are provided" do
      use_cassette "api-oauth-send_otp-correct-register-params", match_requests_on: [:request_body] do
        assert {:ok, state, :register} = OAuth.send_otp(%{email: @email, phone: @new_user})
        assert is_binary(state)
      end
    end

    test "returns an error if the email is nil, empty or not a string" do
      Enum.map [nil, "", 1, :foo], fn email ->
        assert {:error, "`email` must be a non-nil string", _} = OAuth.send_otp(%{email: email, phone: @existing_user})
      end
    end

    test "returns an error if the phone is nil, empty or not a string" do
      Enum.map [nil, "", 1, :foo], fn phone ->
        assert {:error, "`phone` must be a non-nil string", _} = OAuth.send_otp(%{email: @email, phone: phone})
      end
    end

    test "returns :invalid_email when an invalid email is provided" do
      use_cassette "api-oauth-send_otp-invalid-email", match_requests_on: [:request_body] do
        assert {:error, _message, :invalid_email} = OAuth.send_otp(%{email: "foobar", phone: @existing_user})
      end
    end

    test "returns :invalid_email when an invalid phone number is provided" do
      use_cassette "api-oauth-send_otp-invalid-phone", match_requests_on: [:request_body] do
        assert {:error, _message, :invalid_mobile} = OAuth.send_otp(%{email: @email, phone: "12345"})
      end
    end

  end
end
