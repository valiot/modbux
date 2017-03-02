defmodule F01Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model
  alias Modbus.Rtu
  alias Modbus.Tcp

  test "Read 0 from Single Coil" do
    state0 = %{ 0x50=>%{ {:c, 0x5152}=>0 } }
    cmd0 = {:rc, 0x50, 0x5152, 1}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 1, 1, 0x00>>
    val0 = [0]
    pp cmd0, req0, res0, val0, state0
  end

  test "Read 1 from Single Coil" do
    state0 = %{ 0x50=>%{ {:c, 0x5152}=>1 } }
    cmd0 = {:rc, 0x50, 0x5152, 1}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 1, 1, 0x01>>
    val0 = [1]
    pp cmd0, req0, res0, val0, state0
  end

  test "Read 011 from Multiple Coils" do
    state0 = %{ 0x50=>%{
      {:c, 0x5152}=>0, {:c, 0x5153}=>1, {:c, 0x5154}=>1,
    } }
    cmd0 = {:rc, 0x50, 0x5152, 3}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 3>>
    res0 = <<0x50, 1, 1, 0x06>>
    val0 = [0,1,1]
    pp cmd0, req0, res0, val0, state0
  end

  test "Read 0011 1100 0101 from Multiple Coils" do
    state0 = %{ 0x50=>%{
      {:c, 0x5152}=>0, {:c, 0x5153}=>0, {:c, 0x5154}=>1, {:c, 0x5155}=>1,
      {:c, 0x5156}=>1, {:c, 0x5157}=>1, {:c, 0x5158}=>0, {:c, 0x5159}=>0,
      {:c, 0x515A}=>0, {:c, 0x515B}=>1, {:c, 0x515C}=>0, {:c, 0x515D}=>1,
    } }
    cmd0 = {:rc, 0x50, 0x5152, 12}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 12>>
    res0 = <<0x50, 1, 2, 0x3C, 0x0A>>
    val0 = [0,0,1,1, 1,1,0,0, 0,1,0,1]
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
    #master

  end

end
