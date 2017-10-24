defmodule Paytm.API.Wallet do
  use HTTPoison.Base

  @endpoint Application.get_env(:paytm, Paytm)[:wallet_api_base_url]

  def process_url(url) do
    @endpoint <> url
  end
end
