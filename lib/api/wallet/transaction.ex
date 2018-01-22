defmodule Paytm.API.Wallet.Transaction do
  @type t :: %__MODULE__{
    id:                  String.t,
    merchant_id:         String.t,
    merchant_uid:        String.t,
    order_id:            String.t,
    customer_id:         String.t,
    money:               Money.t,
    refunded_money:      Money.t,
    successful:          boolean,
    payment_mode:        String.t,
    bank_name:           String.t,
    bank_transaction_id: String.t,
    gateway_name:        String.t,
    response_code:       String.t,
    response_message:    String.t,
  }

  @required_keys [
    :id,
    :merchant_id,
    :merchant_uid,
    :order_id,
    :customer_id,
    :money,
    :successful,
    :payment_mode,
    :bank_name,
    :bank_transaction_id,
  ]

  @optional_keys [
    :timestamp,
    :refunded_money,
    :gateway_name,
    :response_code,
    :response_message,
  ]

  @enforce_keys @required_keys

  defstruct @required_keys ++ @optional_keys
end
