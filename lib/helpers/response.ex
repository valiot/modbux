defmodule Modbus.Response do
  @moduledoc false
  alias Modbus.Helper

  # @exceptions %{
  #   1 => "Illegal function",
  #   2 => "Illegal data address",
  #   3 => "Illegal data value",
  #   4 => "Slave device failure",
  #   5 => "Acknowledge",
  #   6 => "Slave device busy",
  #   7 => "Negative Acknowledge",
  #   8 => "Memory parity error",
  #   9 => "Unkown error",
  #   10 => "Gateway path unavailable",
  #   11 => "Gateway target device failed to respond",
  # }

  @exceptions %{
    1 => :efun,
    2 => :eaddr,
    3 => :einval,
    4 => :edevice,
    5 => :ack,
    6 => :sbusy,
    7 => :nack,
    8 => :ememp,
    9 => :error,
    10 => :egpath,
    11 => :egtarg
  }

  def pack({:rc, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = Helper.bitlist_to_bin(values)
    reads(slave, 1, data)
  end

  def pack({:ri, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = Helper.bitlist_to_bin(values)
    reads(slave, 2, data)
  end

  def pack({:rhr, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = Helper.reglist_to_bin(values)
    reads(slave, 3, data)
  end

  def pack({:rir, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = Helper.reglist_to_bin(values)
    reads(slave, 4, data)
  end

  def pack({:fc, slave, address, value}, nil) when is_integer(value) do
    write(:d, slave, 5, address, value)
  end

  def pack({:phr, slave, address, value}, nil) when is_integer(value) do
    write(:a, slave, 6, address, value)
  end

  def pack({:fc, slave, address, values}, nil) when is_list(values) do
    writes(:d, slave, 15, address, values)
  end

  def pack({:phr, slave, address, values}, nil) when is_list(values) do
    writes(:a, slave, 16, address, values)
  end

  def parse({:rc, slave, _address, count}, <<slave, 1, bytes, data::binary>>) do
    ^bytes = Helper.byte_count(count)
    Helper.bin_to_bitlist(count, data)
  end

  def parse({:ri, slave, _address, count}, <<slave, 2, bytes, data::binary>>) do
    ^bytes = Helper.byte_count(count)
    Helper.bin_to_bitlist(count, data)
  end

  def parse({:rhr, slave, _address, count}, <<slave, 3, bytes, data::binary>>) do
    ^bytes = 2 * count
    Helper.bin_to_reglist(count, data)
  end

  def parse({:rir, slave, _address, count}, <<slave, 4, bytes, data::binary>>) do
    ^bytes = 2 * count
    Helper.bin_to_reglist(count, data)
  end

  def parse({:fc, slave, address, 0}, <<slave, 5, address::16, 0x00, 0x00>>) do
    nil
  end

  def parse({:fc, slave, address, 1}, <<slave, 5, address::16, 0xFF, 0x00>>) do
    nil
  end

  def parse({:phr, slave, address, value}, <<slave, 6, address::16, value::16>>) do
    nil
  end

  def parse({:fc, slave, address, values}, <<slave, 15, address::16, count::16>>) do
    ^count = Enum.count(values)
    nil
  end

  def parse({:phr, slave, address, values}, <<slave, 16, address::16, count::16>>) do
    ^count = Enum.count(values)
    nil
  end

  # error
  def parse(_cmd, <<_slave, _fc, error_code>>) when error_code in 1..11 do
    {:error, @exceptions[error_code]}
  end

  def parse(_cmd, <<slave, _fc, _error_code>>) do
    {:error, slave, "Unknown error"}
  end

  def length({:rc, _slave, _address, count}) do
    3 + Helper.byte_count(count)
  end

  def length({:ri, _slave, _address, count}) do
    3 + Helper.byte_count(count)
  end

  def length({:rhr, _slave, _address, count}) do
    3 + 2 * count
  end

  def length({:rir, _slave, _address, count}) do
    3 + 2 * count
  end

  def length({:fc, _slave, _address, _}) do
    6
  end

  def length({:phr, _slave, _address, _}) do
    6
  end

  defp reads(slave, function, data) do
    bytes = :erlang.byte_size(data)
    <<slave, function, bytes, data::binary>>
  end

  defp write(:d, slave, function, address, value) do
    <<slave, function, address::16, Helper.bool_to_byte(value), 0x00>>
  end

  defp write(:a, slave, function, address, value) do
    <<slave, function, address::16, value::16>>
  end

  defp writes(_type, slave, function, address, values) do
    count = Enum.count(values)
    <<slave, function, address::16, count::16>>
  end
end
