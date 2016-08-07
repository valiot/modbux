defmodule F4Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model

  test "Read 0x6162 from Single Analog Input" do
    state0 = %{ 0x50=>%{ {:ai, 0x5152}=>0x6162 } }
    cmd0 = {:rai, 0x50, 0x5152, 1}
    req0 = <<0x50, 4, 0x51, 0x52, 0, 1>>
    resp0 = <<0x50, 4, 2, 0x61, 0x62>>
    val0 = [0x6162]
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state0, ^val0} = Model.apply(state0, cmd0)
    ^resp0 = Response.pack(cmd0, val0)
    {^val0, <<>>} = Response.parse(cmd0, resp0)
  end

  test "Read 0x616263646566 from Multiple Analog Inputs" do
    state0 = %{ 0x50=>%{
      {:ai, 0x5152}=>0x6162, {:ai, 0x5153}=>0x6364, {:ai, 0x5154}=>0x6566,
    } }
    cmd0 = {:rai, 0x50, 0x5152, 3}
    req0 = <<0x50, 4, 0x51, 0x52, 0, 3>>
    resp0 = <<0x50, 4, 6, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66>>
    val0 = [0x6162,0x6364,0x6566]
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state0, ^val0} = Model.apply(state0, cmd0)
    ^resp0 = Response.pack(cmd0, val0)
    {^val0, <<>>} = Response.parse(cmd0, resp0)
  end

end
