defmodule Modbus.Response do
  import Modbus.Helper
  @moduledoc false

  def pack({:rc, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = bitlist2bin(values)
    reads(slave, 1, data)
  end

  def pack({:ri, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = bitlist2bin(values)
    reads(slave, 2, data)
  end

  def pack({:rhr, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = registerlist2bin(values)
    reads(slave, 3, data)
  end

  def pack({:rir, slave, _address, count}, values) do
    ^count = Enum.count(values)
    data = registerlist2bin(values)
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
    ^bytes = byte_count(count)
    bin2bitlist(count, data)
  end

  def parse({:ri, slave, _address, count}, <<slave, 2, bytes, data::binary>>) do
    ^bytes = byte_count(count)
    bin2bitlist(count, data)
  end

  def parse({:rhr, slave, _address, count}, <<slave, 3, bytes, data::binary>>) do
    ^bytes = 2 * count
    bin2registerlist(count, data)
  end

  def parse({:rir, slave, _address, count}, <<slave, 4, bytes, data::binary>>) do
    ^bytes = 2 * count
    bin2registerlist(count, data)
  end

  def parse({:fc, slave, address, 0}, <<slave, 5, address::size(16), 0x00, 0x00, tail::binary>>) do
    {nil, tail}
  end

  def parse({:fc, slave, address, 1}, <<slave, 5, address::size(16), 0xFF, 0x00, tail::binary>>) do
    {nil, tail}
  end

  def parse({:phr, slave, address, value}, <<slave, 6, address::size(16), value::size(16), tail::binary>>) do
    {nil, tail}
  end

  def parse({:fc, slave, address, values}, <<slave, 15, address::size(16), count::size(16), tail::binary>>) do
    ^count = Enum.count(values)
    {nil, tail}
  end

  def parse({:phr, slave, address, values}, <<slave, 16, address::size(16), count::size(16), tail::binary>>) do
    ^count = Enum.count(values)
    {nil, tail}
  end

  defp reads(slave, function, data) do
    bytes = :erlang.byte_size(data)
    <<slave, function, bytes, data::binary>>
  end

  defp write(:d, slave, function, address, value) do
    <<slave, function, address::size(16), bool_val(value), 0x00>>
  end

  defp write(:a, slave, function, address, value) do
    <<slave, function, address::size(16), value::size(16)>>
  end

  defp writes(_type, slave, function, address, values) do
    count =  Enum.count(values)
    <<slave, function, address::size(16), count::size(16)>>
  end

end
