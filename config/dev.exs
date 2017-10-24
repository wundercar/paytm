use Mix.Config

config :paytm, Paytm.API.Wallet,
  base_url:          "https://pguat.paytm.com",
  check_balance_url: "https://trust-uat.paytm.in/service/checkUserBalance"

config :paytm, Paytm.API.OAuth,
  base_url: "https://accounts-uat.paytm.com"
