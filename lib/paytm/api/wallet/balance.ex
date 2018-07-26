defmodule Paytm.API.Wallet.Balance do
  @type t :: %__MODULE__{
          total_balance: Money.t(),
          paytm_wallet_balance: Money.t(),
          sub_wallet_balance: Money.t()
        }
  @enforce_keys [:total_balance, :paytm_wallet_balance, :sub_wallet_balance]
  defstruct [:total_balance, :paytm_wallet_balance, :sub_wallet_balance]

  @spec new(
          full_units_or_cents :: atom,
          total_balance :: integer,
          paytm_wallet_balance :: integer,
          sub_wallet_balance :: integer
        ) :: __MODULE__.t()

  def new(:full_units, total_balance, paytm_wallet_balance, sub_wallet_balance) do
    %__MODULE__{
      total_balance: Money.new(trunc(total_balance * 100), :INR),
      paytm_wallet_balance: Money.new(trunc(paytm_wallet_balance * 100), :INR),
      sub_wallet_balance: Money.new(trunc(sub_wallet_balance * 100), :INR)
    }
  end
end
