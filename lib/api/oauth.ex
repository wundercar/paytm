defmodule Paytm.API.OAuth do
  use HTTPoison.Base

  @endpoint Application.get_env(:paytm, Paytm)[:oauth_api_base_url]

  def process_url(url) do
    @endpoint <> url
  end
end
