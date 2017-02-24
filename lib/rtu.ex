defmodule Modbus.Rtu do
  alias Modbus.Helper
  @moduledoc false

  def wrap(payload) do
    crc = Helper.crc(payload)
    <<payload::binary, crc::16>>
  end

  def unwrap(data) do
    size = :erlang.byte_size(data)-2
    <<payload::binary-size(size), crc::16>> = data
    ^crc = Helper.crc(payload)
    payload
  end

end
