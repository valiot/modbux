defmodule RtuTest do
  use ExUnit.Case
  alias Modbus.Rtu

  #http://www.tahapaksu.com/crc/
  #https://www.lammertbies.nl/comm/info/crc-calculation.html
  test "wrap test" do
    p  0xFFFF, <<>>
    p  0x40BF, <<0>>
    p  0x70C0, <<0,1>>
    p  0x91F1, <<0,1,2>>
    p  0x8510, <<0,1,2,3>>
  end

  defp p(crc, payload) do
    assert <<payload::binary, crc::16>> == payload |> Rtu.wrap
    assert payload == <<payload::binary, crc::16>> |> Rtu.unwrap
  end

end
