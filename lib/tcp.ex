defmodule Modbus.Tcp do
  @moduledoc false

  #http://www.simplymodbus.ca/TCP.htm

  def wrap(payload, transid) do
    size =  :erlang.byte_size(payload)
    <<transid::16, 0, 0, size::16, payload::binary>>
  end

  def unwrap(<<transid::16, 0, 0, size::16, payload::binary>>, transid) do
    ^size = :erlang.byte_size(payload)
    payload
  end

  def unwrap(<<transid::16, 0, 0, size::16, payload::binary>>) do
    ^size = :erlang.byte_size(payload)
    {payload, transid}
  end

end
