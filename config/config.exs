use Mix.Config

config :paytm, Paytm.API.Wallet,
  base_url: "https://pguat.paytm.com",
  check_balance_url: "https://trust-uat.paytm.in/service/checkUserBalance",
  merchant_id: System.get_env("PAYTM_MERCHANT_ID"),
  merchant_key: System.get_env("PAYTM_MERCHANT_KEY"),
  merchant_website: System.get_env("PAYTM_MERCHANT_WEBSITE"),
  merchant_industry: System.get_env("PAYTM_MERCHANT_INDUSTRY"),
  callback_url: System.get_env("PAYTM_CALLBACK_URL"),
  default_channel: System.get_env("PAYTM_DEFAULT_CHANNEL"),
  recv_timeout: 30000

config :paytm, Paytm.API.Gratification,
  base_url: "https://trust-uat.paytm.in/",
  default_sales_wallet_name: System.get_env("PAYTM_GRATIFICATION_DEFAULT_SALES_WALLET_NAME"),
  default_sales_wallet_guid: System.get_env("PAYTM_GRATIFICATION_DEFAULT_SALES_WALLET_GUID"),
  merchant_key: System.get_env("PAYTM_GRATIFICATION_MERCHANT_KEY"),
  merchant_guid: System.get_env("PAYTM_GRATIFICATION_MERCHANT_GUID"),
  recv_timeout: 30000

config :paytm, Paytm.API.OAuth,
  base_url: "https://accounts-uat.paytm.com",
  client_id: System.get_env("PAYTM_OAUTH_CLIENT_ID"),
  client_secret: System.get_env("PAYTM_OAUTH_CLIENT_SECRET"),
  recv_timeout: 30000

import_config "#{Mix.env()}.exs"
