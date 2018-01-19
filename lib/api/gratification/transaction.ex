defmodule Paytm.API.Gratification.Transaction do
  @type t :: %__MODULE__{
    id:                  String.t,
    order_id:            String.t,
    money:               Money.t,
    status:              :init | :success | :failure | :pending,
  }

  @all_keys [
    :id,
    :order_id,
    :money,
    :status,
  ]

  @enforce_keys @all_keys

  defstruct @all_keys
end
