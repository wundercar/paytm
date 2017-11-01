defmodule Paytm.API.OAuth do
  alias Paytm.API.OAuth.Token

  @error_codes %{
    "403" => :invalid_otp,
    "430" => :invalid_authorization,
    "431" => :invalid_mobile,
    "432" => :login_failed,
    "433" => :account_blocked,
    "434" => :bad_request,
    "465" => :invalid_email,
    "513" => :invalid_code,
    "530" => :invalid_token,
  }

  @spec send_otp(%{email: String.t, phone: String.t})
        :: {:ok, state :: String.t, :login}
        |  {:ok, state :: String.t, :register}
        |  {:error, message :: String.t | atom, code :: atom}
  def send_otp(%{email: email}) when not is_binary(email) or email == "" do
    {:error, "`email` must be a non-nil string", :invalid_email}
  end
  def send_otp(%{phone: phone}) when not is_binary(phone) or phone == "" do
    {:error, "`phone` must be a non-nil string", :invalid_mobile}
  end
  def send_otp(%{email: _, phone: _} = params) do
    params = Map.merge(params, %{clientId: config(:client_id), scope: "wallet", responseType: "token"})
    body = Poison.encode!(params)

    "/signin/otp"
    |> add_base_url
    |> HTTPoison.post(body)
    |> handle_response
    |> case do
      {:ok, %{"status" => "SUCCESS", "responseCode" => "01", "state" => state}} ->
        {:ok, state, :login}
      {:ok, %{"status" => "SUCCESS", "responseCode" => "02", "state" => state}} ->
        {:ok, state, :register}
      {:error, message, code} -> {:error, message, code}
      _ -> {:error, "An unknown error occurred", nil}
    end
  end
  def send_otp(_), do: {:error, "`email` and `phone` are required", nil}

  @spec validate_otp(otp :: String.t, state :: String.t)
        :: {:ok, token :: Token.t}
        |  {:error, message :: String.t | atom, code :: atom}
  def validate_otp(otp, state) do
    body = Poison.encode!(%{otp: otp, state: state})

    "/signin/validate/otp"
    |> add_base_url
    |> HTTPoison.post(body, [authorization_header()])
    |> handle_response
    |> case do
      {:ok, %{"access_token" => access_token,
              "expires" => expires_at,
              "scope" => scope,
              "resourceOwnerId" => customer_id}} ->
        {:ok, %Token{access_token: access_token,
                     expires_at: to_integer(expires_at),
                     scope: scope,
                     customer_id: to_string(customer_id)}}
      {:error, message, code} -> {:error, message, code}
      _ -> {:error, "An unknown error occurred", nil}
    end
  end

  @spec validate_token(token :: Token.t | String.t)
        :: {:ok, token :: Token.t}
        |  {:error, message :: String.t | atom, code :: atom}
  def validate_token(token) when is_binary(token) and token != "" do
    validate_token(%Token{access_token: token})
  end
  def validate_token(%Token{access_token: access_token} = token) do
    "/user/details"
    |> add_base_url
    |> HTTPoison.get([{"session_token", access_token}])
    |> handle_response
    |> case do
      {:ok, %{"id" => customer_id,
              "email" => email,
              "mobile" => phone,
              "expires" => expires_at}} ->
        {:ok, %Token{token |
                     customer_id: to_string(customer_id),
                     expires_at: to_integer(expires_at),
                     email: email,
                     phone: to_string(phone)}}
      {:error, message, code} -> {:error, message, code}
      _ -> {:error, "An unknown error occurred", nil}
    end
  end

  defp config(key) when is_atom(key) do
    Application.get_env(:paytm, Paytm.API.OAuth)[key]
  end

  defp add_base_url(url) do
    config(:base_url)
    |> URI.merge(url)
    |> URI.to_string
  end

  defp authorization_header do
    {"Authorization", "Basic #{Base.encode64("#{config(:client_id)}:#{config(:client_secret)}")}}"}
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}), do: {:error, "", reason}
  defp handle_response({:ok, %HTTPoison.Response{body: ""}}), do: {:ok, %{}}
  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    body
    |> Poison.decode!
    |> handle_body
  end
  defp handle_response(_), do: {:error, "An unknown error occurred", nil}

  defp handle_body(%{"status" => "FAILURE", "responseCode" => code, "message" => message}), do: {:error, message, @error_codes[code]}
  defp handle_body(%{} = body), do: {:ok, body}

  defp to_integer(integer) when is_integer(integer), do: integer
  defp to_integer(string) when is_binary(string), do: String.to_integer(string)
end
