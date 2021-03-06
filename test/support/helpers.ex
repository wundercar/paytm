defmodule Paytm.Support.Helpers do
  def random_id do
    UUID.uuid4()
    |> String.slice(0, 8)
  end

  def random_phone do
    "#{Enum.random(7..9)}#{Enum.random(100_000_000..999_999_999)}"
  end
end
