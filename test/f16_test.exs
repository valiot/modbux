defmodule F16Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model

  test "Write 0x616263646566 to Multiple Holding Registers" do
    state0 = %{ 0x50=>%{
      {:hr, 0x5152}=>0, {:hr, 0x5153}=>0, {:hr, 0x5154}=>0,
    } }
    state1 = %{ 0x50=>%{
      {:hr, 0x5152}=>0x6162, {:hr, 0x5153}=>0x6364, {:hr, 0x5154}=>0x6566,
    } }
    val0 = [0x6162,0x6364,0x6566]
    cmd0 = {:phr, 0x50, 0x5152, val0}
    req0 = <<0x50, 16, 0x51, 0x52, 0, 3, 6, 0x61,0x62, 0x63,0x64, 0x65,0x66>>
    res0 = <<0x50, 16, 0x51, 0x52, 0, 3>>
    ^req0 = Request.pack(cmd0)
    ^cmd0 = Request.parse(req0)
    {^state1, nil} = Model.apply(state0, cmd0)
    ^res0 = Response.pack(cmd0, nil)
    nil = Response.parse(cmd0, res0)
  end

end
