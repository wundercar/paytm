defmodule Paytm.API.OAuth.Token do
  @type t :: %__MODULE__{
          access_token: String.t(),
          expires_at: integer | nil,
          scope: String.t() | nil,
          customer_id: String.t() | nil,
          email: String.t() | nil,
          phone: String.t() | nil
        }
  @enforce_keys [:access_token]
  defstruct [
    :access_token,
    :expires_at,
    :scope,
    :customer_id,
    :email,
    :phone
  ]
end
