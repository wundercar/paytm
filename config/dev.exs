use Mix.Config

config :paytm, Paytm,
  oauth_api_base_url: "https://accounts-uat.paytm.com",
  wallet_api_base_url: "https://pguat.paytm.com"

config :paytm, Paytm.API.OAuth,
  client_id: "",
  client_secret: ""
