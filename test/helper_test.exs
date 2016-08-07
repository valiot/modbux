defmodule HelperTest do
  use ExUnit.Case
  alias Modbus.Helper

  test "bool_val test" do
    0x00 = Helper.bool_val(0)
    0xFF = Helper.bool_val(1)
  end

  test "byte_count test" do
    1 = Helper.byte_count(1)
    1 = Helper.byte_count(2)
    1 = Helper.byte_count(7)
    1 = Helper.byte_count(8)
    2 = Helper.byte_count(9)
    2 = Helper.byte_count(15)
    2 = Helper.byte_count(16)
    3 = Helper.byte_count(17)
  end

  test "bin2bitlist test" do
    {[1], <<>>} = Helper.bin2bitlist(1, <<0x13>>)
    {[1, 1], <<>>} = Helper.bin2bitlist(2, <<0x13>>)
    {[1, 1, 0], <<>>} = Helper.bin2bitlist(3, <<0x13>>)
    {[1, 1, 0, 0], <<>>} = Helper.bin2bitlist(4, <<0x13>>)
    {[1, 1, 0, 0, 1], <<>>} = Helper.bin2bitlist(5, <<0x13>>)
    {[1, 1, 0, 0, 1, 0], <<>>} = Helper.bin2bitlist(6, <<0x13>>)
    {[1, 1, 0, 0, 1, 0, 0], <<0xAA>>} = Helper.bin2bitlist(7, <<0x13, 0xAA>>)
    {[1, 1, 0, 0, 1, 0, 0, 0], <<>>} = Helper.bin2bitlist(8, <<0x13>>)
    {[1, 1, 0, 0, 1, 0, 0, 0, 1], <<>>} = Helper.bin2bitlist(9, <<0x13, 0x01>>)
    {[1, 1, 0, 0, 1, 0, 0, 0, 1], <<0xAA>>} = Helper.bin2bitlist(9, <<0x13, 0x01, 0xAA>>)
  end

  test "bin2registerlist test" do
    {[0x0102], <<>>} = Helper.bin2registerlist(1, <<0x01, 0x02>>)
    {[0x0102], <<0xAA>>} = Helper.bin2registerlist(1, <<0x01, 0x02, 0xAA>>)
    {[0x0102, 0x0304], <<>>} = Helper.bin2registerlist(2, <<0x01, 0x02, 0x03, 0x04>>)
    {[0x0102, 0x0304], <<0xAA>>} = Helper.bin2registerlist(2, <<0x01, 0x02, 0x03, 0x04, 0xAA>>)
  end
end
