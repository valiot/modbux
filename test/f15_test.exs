defmodule F15Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model
  alias Modbus.Rtu
  alias Modbus.Tcp

  test "Write 011 to Multiple Coils" do
    state0 = %{ 0x50=>%{
      {:c, 0x5152}=>1, {:c, 0x5153}=>0, {:c, 0x5154}=>0,
    } }
    state1 = %{ 0x50=>%{
      {:c, 0x5152}=>0, {:c, 0x5153}=>1, {:c, 0x5154}=>1,
    } }
    val0 = [0,1,1]
    cmd0 = {:fc, 0x50, 0x5152, val0}
    req0 = <<0x50, 15, 0x51, 0x52, 0, 3, 1, 0x06>>
    res0 = <<0x50, 15, 0x51, 0x52, 0, 3>>
    pp cmd0, req0, res0, state0, state1
  end

  test "Write 0011 1100 0101 to Multiple Coils" do
    state0 = %{ 0x50=>%{
      {:c, 0x5152}=>1, {:c, 0x5153}=>1, {:c, 0x5154}=>0, {:c, 0x5155}=>0,
      {:c, 0x5156}=>0, {:c, 0x5157}=>0, {:c, 0x5158}=>1, {:c, 0x5159}=>1,
      {:c, 0x515A}=>1, {:c, 0x515B}=>0, {:c, 0x515C}=>1, {:c, 0x515D}=>0,
    } }
    state1 = %{ 0x50=>%{
      {:c, 0x5152}=>0, {:c, 0x5153}=>0, {:c, 0x5154}=>1, {:c, 0x5155}=>1,
      {:c, 0x5156}=>1, {:c, 0x5157}=>1, {:c, 0x5158}=>0, {:c, 0x5159}=>0,
      {:c, 0x515A}=>0, {:c, 0x515B}=>1, {:c, 0x515C}=>0, {:c, 0x515D}=>1,
    } }
    val0 = [0,0,1,1, 1,1,0,0, 0,1,0,1]
    cmd0 = {:fc, 0x50, 0x5152, val0}
    req0 = <<0x50, 15, 0x51, 0x52, 0, 12, 2, 0x3C, 0x0A>>
    res0 = <<0x50, 15, 0x51, 0x52, 0, 12>>
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
