defmodule Paytm.API.OAuth.Token do
  @enforce_keys [:access_token]
  defstruct [
    :access_token,
    :expires_at,
    :scope,
    :customer_id,
    :email,
    :phone,
  ]
end
