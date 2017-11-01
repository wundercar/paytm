defmodule Paytm.API.Wallet.Transaction do
  @type t :: %__MODULE__{
    id:                  String.t,
    merchant_id:         String.t,
    merchant_uid:        String.t,
    order_id:            String.t,
    customer_id:         String.t,
    money:               Money.t,
    successful:          bool,
    payment_mode:        String.t,
    bank_name:           String.t,
    bank_transaction_id: String.t,
  }

  @all_keys [
    :id,
    :merchant_id,
    :merchant_uid,
    :order_id,
    :customer_id,
    :money,
    :successful,
    :payment_mode,
    :bank_name,
    :bank_transaction_id
  ]

  @enforce_keys @all_keys

  defstruct @all_keys
end
