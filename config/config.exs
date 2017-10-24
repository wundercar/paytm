use Mix.Config

config :paytm, Paytm.API.Wallet,
  merchant_id: System.get_env("PAYTM_MERCHANT_ID"),
  merchant_key: System.get_env("PAYTM_MERCHANT_KEY"),
  callback_url: System.get_env("PAYTM_CALLBACK_URL")

config :paytm, Paytm.API.OAuth,
  client_id: System.get_env("PAYTM_OAUTH_CLIENT_ID"),
  client_secret: System.get_env("PAYTM_OAUTH_CLIENT_SECRET")

import_config "#{Mix.env}.exs"
