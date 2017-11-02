defmodule Paytm.Checksum do
  @salt_length 4
  @aes_block_size 16
  @iv "@@@@&&&&####$$$$"

  @spec generate(parameters :: map, salt :: String.t) :: String.t
  def generate(parameters, salt \\ generate_salt()) do
    parameters
    |> Map.keys
    |> Enum.sort
    |> Enum.map(&(parameters[&1]))
    |> Enum.join("|")
    |> append("|" <> salt)
    |> hash
    |> append(salt)
    |> encrypt
  end

  @spec valid_checksum?(parameters :: map, checksum :: String.t) :: boolean
  def valid_checksum?(parameters, checksum) do
    salt =
      checksum
      |> decrypt
      |> String.slice(-@salt_length, @salt_length)

    checksum == generate(parameters, salt)
  end

  defp encrypt(binary, key \\ merchant_key()) do
    :crypto.block_encrypt(:aes_cbc128, key, @iv, pad(binary, @aes_block_size))
    |> Base.encode64
  end

  defp decrypt(binary, key \\ merchant_key()) do
    with {:ok, data} <- Base.decode64(binary) do
      :crypto.block_decrypt(:aes_cbc128, key, @iv, data)
      |> unpad
    end
  end

  defp hash(string) do
    :crypto.hash(:sha256, string)
    |> Base.encode16
    |> String.downcase
  end

  defp pad(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> to_string(:string.chars(to_add, to_add))
  end

  defp unpad(data) do
    to_remove = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - to_remove)
  end

  defp append(string, append), do: string <> append

  defp generate_salt(length \\ @salt_length) do
    length
    |> :crypto.strong_rand_bytes
    |> Base.url_encode64
    |> binary_part(0, length)
  end

  defp merchant_key do
    Application.get_env(:paytm, Paytm.API.Wallet)[:merchant_key] || throw("Merchant key not set")
  end
end
