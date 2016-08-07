defmodule F6Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model

  test "Write 0x6162 to Single Analog Output" do
    state0 = %{ 0x50=>%{ {:ao, 0x5152}=>0 } }
    state1 = %{ 0x50=>%{ {:ao, 0x5152}=>0x6162 } }
    val0 = 0x6162
    cmd0 = {:wao, 0x50, 0x5152, val0}
    req0 = <<0x50, 6, 0x51, 0x52, 0x61, 0x62>>
    resp0 = <<0x50, 6, 0x51, 0x52, 0x61, 0x62>>
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state1, nil} = Model.apply(state0, cmd0)
    ^resp0 = Response.pack(cmd0, nil)
    {nil, <<>>} = Response.parse(cmd0, resp0)
  end

end
