use Mix.Config

config :paytm, Paytm.API.Wallet,
  hackney_insecure: true

config :paytm, Paytm.API.Gratification,
  hackney_insecure: true

config :paytm, Paytm.API.OAuth,
  hackney_insecure: true
