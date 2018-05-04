defmodule Paytm.Checksum do
  @salt_length 4
  @aes_block_size 16
  @iv "@@@@&&&&####$$$$"

  @spec generate(payload :: map | String.t, api_module :: module, salt :: String.t) :: String.t
  def generate(_, api_module \\ Paytm.API.Wallet, salt \\ generate_salt())

  def generate(%{} = parameters, api_module, salt) do
    parameters
    |> Map.keys
    |> Enum.sort
    |> Enum.map(&(parameters[&1]))
    |> Enum.join("|")
    |> generate(api_module, salt)
  end

  def generate(string, api_module, salt) when is_binary(string) do
    string
    |> append("|" <> salt)
    |> hash
    |> append(salt)
    |> encrypt(merchant_key(api_module))
  end

  @spec valid_checksum?(parameters :: map, checksum :: String.t) :: boolean
  def valid_checksum?(parameters, checksum, api_module \\ Paytm.API.Wallet) do
    salt =
      checksum
      |> decrypt(merchant_key(api_module))
      |> String.slice(-@salt_length, @salt_length)

    checksum == generate(parameters, api_module, salt)
  end

  defp encrypt(binary, key) do
    :crypto.block_encrypt(:aes_cbc128, key, @iv, pad(binary, @aes_block_size))
    |> Base.encode64
  end

  defp decrypt(binary, key) do
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

  defp merchant_key(module) do
    Application.get_env(:paytm, module)[:merchant_key] || throw("Merchant key not set")
  end
end
