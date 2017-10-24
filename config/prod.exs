use Mix.Config

config :paytm, Paytm.API.Wallet,
  base_url: "https://secure.paytm.in"

config :paytm, Paytm.API.OAuth,
  base_url: "https://accounts.paytm.com",
  client_id: "",
  client_secret: ""
