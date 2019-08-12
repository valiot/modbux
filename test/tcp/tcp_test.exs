defmodule TcpTest do
  use ExUnit.Case
  alias Modbux.Tcp

  # http://www.tahapaksu.com/crc/
  # https://www.lammertbies.nl/comm/info/crc-calculation.html
  test "wrap test" do
    p(0, <<>>, <<0, 0, 0, 0, 0, 0>>)
    p(1, <<0>>, <<0, 1, 0, 0, 0, 1, 0>>)
    p(2, <<0, 1>>, <<0, 2, 0, 0, 0, 2, 0, 1>>)
    p(3, <<0, 1, 2>>, <<0, 3, 0, 0, 0, 3, 0, 1, 2>>)
    p(4, <<0, 1, 2, 3>>, <<0, 4, 0, 0, 0, 4, 0, 1, 2, 3>>)
  end

  defp p(transid, payload, packet) do
    assert packet == payload |> Tcp.wrap(transid)
    assert {payload, transid} == packet |> Tcp.unwrap()
  end
end
