use Mix.Config

config :paytm, Paytm.API.Wallet,
  base_url: "https://secure.paytm.in",
  check_balance_url: "https://trust.paytm.in/service/checkUserBalance"

config :paytm, Paytm.API.OAuth, base_url: "https://accounts.paytm.com"
