defmodule RtuTest do
  use ExUnit.Case
  alias Modbus.Rtu

  #http://www.simplymodbus.ca/crc.xls
  test "wrap test" do
    p  <<0xFF, 0xFF>>, <<>>
    p  <<0xBF, 0x40>>, <<0>>
    p  <<0xC0, 0x70>>, <<0,1>>
    p  <<0xF1, 0x91>>, <<0,1,2>>
    p  <<0x10, 0x85>>, <<0,1,2,3>>
    p  <<0x4F, 0xCB>>, <<0x01, 0x05, 0x0B, 0xB8, 0x00, 0x00>>
    p  <<0x0E, 0x3B>>, <<0x01, 0x05, 0x0B, 0xB8, 0xFF, 0x00>>
  end

  defp p(<<crc_hi, crc_lo>>, payload) do
    assert <<payload::binary, crc_hi, crc_lo>> == payload |> Rtu.wrap
    assert payload == <<payload::binary, crc_hi, crc_lo>> |> Rtu.unwrap
  end

end
