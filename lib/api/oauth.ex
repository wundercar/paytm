defmodule Paytm.API.OAuth do
  use HTTPoison.Base

  @config        Application.get_env(:paytm, Paytm.API.OAuth)
  @base_url      @config[:base_url]
  @client_id     @config[:client_id]
  @client_secret @config[:client_secret]

  def process_url(url) do
    @base_url <> url
  end
end
