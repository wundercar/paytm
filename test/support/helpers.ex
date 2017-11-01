defmodule Paytm.Support.Helpers do
  def random_id do
    UUID.uuid4
    |> String.slice(0, 8)
  end
end
