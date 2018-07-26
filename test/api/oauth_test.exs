defmodule Paytm.API.OAuthTest do
  use   Paytm.DataCase
  alias Paytm.API.OAuth
  alias OAuth.Token

  setup do
    ExVCR.Config.filter_sensitive_data(~s("clientId":".*"), ~s("clientId":"CLIENT_ID"))
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_headers("Set-Cookie")

    :ok
  end

  @email             "foo@bar.com"
  @new_user          "9900990099"
  @existing_user     "7777777777"
  @existing_user_otp "489871"

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

    test "returns :invalid_email if the email is nil, empty or not a string" do
      Enum.map [nil, "", 1, :foo], fn email ->
        assert {:error, "`email` must be a non-nil string", :invalid_email} = OAuth.send_otp(%{email: email, phone: @existing_user})
      end
    end

    test "returns :invalid_mobile if the phone is nil, empty or not a string" do
      Enum.map [nil, "", 1, :foo], fn phone ->
        assert {:error, "`phone` must be a non-nil string", :invalid_mobile} = OAuth.send_otp(%{email: @email, phone: phone})
      end
    end

    test "returns :invalid_email when an invalid email is provided" do
      use_cassette "api-oauth-send_otp-invalid-email", match_requests_on: [:request_body] do
        assert {:error, _, :invalid_email} = OAuth.send_otp(%{email: "foobar", phone: @existing_user})
      end
    end

    test "returns :invalid_mobile when an invalid phone number is provided" do
      use_cassette "api-oauth-send_otp-invalid-phone", match_requests_on: [:request_body] do
        assert {:error, _, :invalid_mobile} = OAuth.send_otp(%{email: @email, phone: "12345"})
      end
    end
  end

  describe "validate_otp/2" do
    test "returns a Token when a valid OTP is provided" do
      use_cassette "api-oauth-validate_otp-valid-otp", match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:ok, %Token{} = token} = OAuth.validate_otp(@existing_user_otp, state)

        assert token.access_token
        assert token.scope
        assert token.customer_id
        assert token.expires_at

        assert is_binary(token.customer_id)
        assert is_integer(token.expires_at)
      end
    end
    test "returns :invalid_otp when an invalid OTP is provided" do
      use_cassette "api-oauth-validate_otp-invalid-otp", match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:error, _, :invalid_otp} = OAuth.validate_otp("111111", state)
      end
    end
    test "returns :invalid_code when an invalid code is provided" do
      use_cassette "api-oauth-validate_otp-invalid-code", match_requests_on: [:request_body] do
        assert {:error, _, :invalid_code} = OAuth.validate_otp(@existing_user_otp, "foo")
      end
    end
  end

  describe "validate_token/1" do
    test "validates successfully with a valid Token" do
      use_cassette "api-oauth-validate_token-valid-token", match_requests_on: [:request_body] do
        assert {:ok, state, _} = OAuth.send_otp(%{email: @email, phone: @existing_user})
        assert {:ok, %Token{} = token} = OAuth.validate_otp(@existing_user_otp, state)
        assert {:ok, %Token{} = validated_token} = OAuth.validate_token(token)

        assert token.access_token == validated_token.access_token
        assert token.expires_at   == validated_token.expires_at
        assert token.scope        == validated_token.scope
        assert token.customer_id  == validated_token.customer_id

        refute token.email
        refute token.phone

        assert validated_token.email
        assert validated_token.phone

        assert is_binary(validated_token.email)
        assert is_binary(validated_token.phone)
      end
    end
    test "returns :invalid_token when an invalid OTP is provided" do
      use_cassette "api-oauth-validate_token-invalid-token", match_requests_on: [:request_body] do
        assert {:error, _, :invalid_token} = OAuth.validate_token("foobar")
      end
    end
  end
end
