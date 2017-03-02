defmodule F04Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model
  alias Modbus.Rtu
  alias Modbus.Tcp

  test "Read 0x6162 from Single Input Register" do
    state0 = %{ 0x50=>%{ {:ir, 0x5152}=>0x6162 } }
    cmd0 = {:rir, 0x50, 0x5152, 1}
    req0 = <<0x50, 4, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 4, 2, 0x61, 0x62>>
    val0 = [0x6162]
    pp cmd0, req0, res0, val0, state0
  end

  test "Read 0x616263646566 from Multiple Input Registers" do
    state0 = %{ 0x50=>%{
      {:ir, 0x5152}=>0x6162, {:ir, 0x5153}=>0x6364, {:ir, 0x5154}=>0x6566,
    } }
    cmd0 = {:rir, 0x50, 0x5152, 3}
    req0 = <<0x50, 4, 0x51, 0x52, 0, 3>>
    res0 = <<0x50, 4, 6, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66>>
    val0 = [0x6162,0x6364,0x6566]
    pp cmd0, req0, res0, val0, state0
  end

  defp pp(cmd, req, res, val, state) do
    assert req == Request.pack(cmd)
    assert cmd == Request.parse(req)
    assert {state, val} == Model.apply(state, cmd)
    assert res == Response.pack(cmd, val)
    assert val == Response.parse(cmd, res)
    #length predition
    assert byte_size(res) == Response.length(cmd)
    #rtu
    rtu_req = Rtu.pack_req(cmd)
    assert cmd == Rtu.parse_req(rtu_req)
    rtu_res = Rtu.pack_res(cmd, val)
    assert val == Rtu.parse_res(cmd, rtu_res)
    #tcp
    tcp_req = Tcp.pack_req(cmd, 1)
    assert {cmd, 1} == Tcp.parse_req(tcp_req)
    tcp_res = Tcp.pack_res(cmd, val, 1)
    assert val == Tcp.parse_res(cmd, tcp_res, 1)
  end

end
