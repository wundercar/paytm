defmodule Paytm.API.Wallet do
  use HTTPoison.Base

  defp config(key) when is_atom(key) do
    Application.get_env(:paytm, Paytm.API.Wallet)[key]
  end

  defp base_url, do: config(:base_url)

  def process_url(url) do
    base_url() <> url
  end
end
