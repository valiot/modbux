defmodule HelperTest do
  use ExUnit.Case
  alias Modbus.Helper

  test "bool_to_byte test" do
    assert 0x00 == Helper.bool_to_byte(0)
    assert 0xFF == Helper.bool_to_byte(1)
  end

  test "byte_count test" do
    assert 1 == Helper.byte_count(1)
    assert 1 == Helper.byte_count(2)
    assert 1 == Helper.byte_count(7)
    assert 1 == Helper.byte_count(8)
    assert 2 == Helper.byte_count(9)
    assert 2 == Helper.byte_count(15)
    assert 2 == Helper.byte_count(16)
    assert 3 == Helper.byte_count(17)
  end

  test "bin_to_bitlist test" do
    assert [1] == Helper.bin_to_bitlist(1, <<0x13>>)
    assert [1, 1] == Helper.bin_to_bitlist(2, <<0x13>>)
    assert [1, 1, 0] == Helper.bin_to_bitlist(3, <<0x13>>)
    assert [1, 1, 0, 0] == Helper.bin_to_bitlist(4, <<0x13>>)
    assert [1, 1, 0, 0, 1] == Helper.bin_to_bitlist(5, <<0x13>>)
    assert [1, 1, 0, 0, 1, 0] == Helper.bin_to_bitlist(6, <<0x13>>)
    assert [1, 1, 0, 0, 1, 0, 0] == Helper.bin_to_bitlist(7, <<0x13>>)
    assert [1, 1, 0, 0, 1, 0, 0, 0] == Helper.bin_to_bitlist(8, <<0x13>>)
    assert [1, 1, 0, 0, 1, 0, 0, 0, 1] == Helper.bin_to_bitlist(9, <<0x13, 0x01>>)
  end

  test "bin_to_reglist test" do
    assert [0x0102] == Helper.bin_to_reglist(1, <<0x01, 0x02>>)
    assert [0x0102, 0x0304] == Helper.bin_to_reglist(2, <<0x01, 0x02, 0x03, 0x04>>)
  end

  #http://www.tahapaksu.com/crc/
  #https://www.lammertbies.nl/comm/info/crc-calculation.html
  test "crc test" do
    p  <<>>, 0xFFFF
    p  <<0x00>>, 0x40BF
    p  <<0x00, 0x01>>, 0x70C0
    p  <<0x00, 0x01, 0x02>>, 0x91F1
    p  <<0x00, 0x01, 0x02, 0x03>>, 0x8510
  end

  defp p(bin, val) do
    assert Integer.to_char_list(val, 16) == bin |> Helper.crc |> Integer.to_char_list(16)
  end

end
