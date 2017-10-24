use Mix.Config

config :paytm, Paytm.API.Wallet,
  base_url: "https://pguat.paytm.com"

config :paytm, Paytm.API.OAuth,
  base_url: "https://accounts-uat.paytm.com",
  client_id: "",
  client_secret: ""
