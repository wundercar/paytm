defmodule Paytm.API.OAuth do
  use HTTPoison.Base

  defp config(key) when is_atom(key) do
    Application.get_env(:paytm, Paytm.API.OAuth)[key]
  end

  defp base_url,       do: config(:base_url)
  defp client_id,      do: config(:client_id)
  defp client_secret,  do: config(:client_secret)

  def process_url(url) do
    base_url <> url
  end

  @send_otp_error_codes %{
    "430" => :invalid_authorization,
    "431" => :invalid_mobile,
    "432" => :login_failed,
    "433" => :account_blocked,
    "434" => :bad_request,
    "465" => :invalid_email
  }

  @spec send_otp(%{email: String.t, phone: String.t}) :: {:ok, state :: String.t, :login}
                                                      |  {:ok, state :: String.t, :register}
                                                      |  {:error, message :: String.t | atom, code :: atom}
  def send_otp(%{email: email}) when not is_binary(email) or email == "", do: {:error, "`email` must be a non-nil string", nil}
  def send_otp(%{phone: phone}) when not is_binary(phone) or phone == "", do: {:error, "`phone` must be a non-nil string", nil}
  def send_otp(%{email: _, phone: _} = params) do
    params = Map.merge(params, %{clientId: client_id, scope: "wallet", responseType: "token"})
    body = Poison.encode!(params)

    "/signin/otp"
    |> post(body)
    |> handle_response
    |> case do
      {:ok, %{"status" => "SUCCESS", "responseCode" => "01", "state" => state}} ->
        {:ok, state, :login}
      {:ok, %{"status" => "SUCCESS", "responseCode" => "02", "state" => state}} ->
        {:ok, state, :register}
      {:error, message, code} ->
        {:error, message, @send_otp_error_codes[code]}
      _ ->
        {:error, "An unknown error occurred", nil}
    end
  end
  def send_otp(_), do: {:error, "`email` and `phone` are required", nil}

  defp handle_response({:error, %HTTPoison.Error{id: id, reason: reason}}), do: {:error, reason, id}
  defp handle_response({:ok, %HTTPoison.Response{body: ""}}), do: {:ok, %{}}
  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    body
    |> Poison.decode!
    |> handle_body
  end
  defp handle_response(_), do: {:error, "An unknown error occurred", nil}

  defp handle_body(%{"status" => "FAILURE", "responseCode" => code, "message" => message}), do: {:error, message, code}
  defp handle_body(%{} = body), do: {:ok, body}
end
