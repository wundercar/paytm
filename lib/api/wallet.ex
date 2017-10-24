defmodule Paytm.API.Wallet do
  use HTTPoison.Base

  @base_url Application.get_env(:paytm, Paytm.API.Wallet)[:base_url]

  def process_url(url) do
    @base_url <> url
  end
end
