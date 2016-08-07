defmodule Modbus.Helper do
  use Bitwise

  def byte_count(count) do
    div(count - 1, 8) + 1
  end

  def bool_val(value) do
    case value do
      0 -> 0x00
      _ -> 0xFF
    end
  end

  def bin2bitlist(count, bin) when count<=8 do
    <<b, tail::binary>> = bin
    << b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1, b0::1 >> = << b >>
    list = [b0, b1, b2, b3, b4, b5, b6, b7]
    {Enum.take(list, count), tail}
  end

  def bin2bitlist(count, bin) do
    <<b, tail::binary>> = bin
    << b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1, b0::1 >> = << b >>
    list = [b0, b1, b2, b3, b4, b5, b6, b7]
    {list2, tail2} = bin2bitlist(count - 8, tail)
    {list ++ list2, tail2}
  end

  def bin2registerlist(1, bin) do
    <<register::size(16), tail::binary>> = bin
    {[register], tail}
  end

  def bin2registerlist(count, bin) do
    <<register::size(16), tail::binary>> = bin
    {list2, tail2} = bin2registerlist(count - 1, tail)
    {[register | list2], tail2}
  end

  def bitlist2bin(values) do
    lists = Enum.chunk(values, 8, 8, [0, 0, 0, 0, 0, 0, 0, 0])
    list = for list8 <- lists do
      [v0, v1, v2, v3, v4, v5, v6, v7] = list8
      << v7::1, v6::1, v5::1, v4::1, v3::1, v2::1, v1::1, v0::1 >>
    end
    :erlang.iolist_to_binary(list)
  end

  def registerlist2bin(values) do
    list = for value <- values do
      <<value::size(16)>>
    end
    :erlang.iolist_to_binary(list)
  end

end
