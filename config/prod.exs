use Mix.Config

config :paytm, Paytm,
  oauth_api_base_url: "https://accounts.paytm.com",
  wallet_api_base_url: "https://secure.paytm.in"

config :paytm, Paytm.API.OAuth,
  client_id: "",
  client_secret: ""
