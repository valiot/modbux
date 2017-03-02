defmodule F06Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model
  alias Modbus.Rtu
  alias Modbus.Tcp

  test "Write 0x6162 to Single Holding Register" do
    state0 = %{ 0x50=>%{ {:hr, 0x5152}=>0 } }
    state1 = %{ 0x50=>%{ {:hr, 0x5152}=>0x6162 } }
    val0 = 0x6162
    cmd0 = {:phr, 0x50, 0x5152, val0}
    req0 = <<0x50, 6, 0x51, 0x52, 0x61, 0x62>>
    res0 = <<0x50, 6, 0x51, 0x52, 0x61, 0x62>>
    pp cmd0, req0, res0, state0, state1
  end

  defp pp(cmd, req, res, state0, state1) do
    assert req == Request.pack(cmd)
    assert cmd == Request.parse(req)
    assert {state1, nil} == Model.apply(state0, cmd)
    assert res == Response.pack(cmd, nil)
    assert nil == Response.parse(cmd, res)
    #length predition
    assert byte_size(res) == Response.length(cmd)
    #rtu
    rtu_req = Rtu.pack_req(cmd)
    assert cmd == Rtu.parse_req(rtu_req)
    rtu_res = Rtu.pack_res(cmd, nil)
    assert nil == Rtu.parse_res(cmd, rtu_res)
    #tcp
    tcp_req = Tcp.pack_req(cmd, 1)
    assert {cmd, 1} == Tcp.parse_req(tcp_req)
    tcp_res = Tcp.pack_res(cmd, nil, 1)
    assert nil == Tcp.parse_res(cmd, tcp_res, 1)
  end

end
