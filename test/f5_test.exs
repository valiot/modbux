defmodule F5Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model

  test "Write 0 to Single Digital Output" do
    state0 = %{ 0x50=>%{ {:hr, 0x5152}=>1 } }
    state1 = %{ 0x50=>%{ {:hr, 0x5152}=>0 } }
    val0 = 0
    cmd0 = {:fc, 0x50, 0x5152, val0}
    req0 = <<0x50, 5, 0x51, 0x52, 0, 0>>
    res0 = <<0x50, 5, 0x51, 0x52, 0, 0>>
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state1, nil} = Model.apply(state0, cmd0)
    ^res0 = Response.pack(cmd0, nil)
    {nil, <<>>} = Response.parse(cmd0, res0)
  end

  test "Write 1 to Single Digital Output" do
    state0 = %{ 0x50=>%{ {:hr, 0x5152}=>0 } }
    state1 = %{ 0x50=>%{ {:hr, 0x5152}=>1 } }
    val0 = 1
    cmd0 = {:fc, 0x50, 0x5152, val0}
    req0 = <<0x50, 5, 0x51, 0x52, 0xFF, 0>>
    res0 = <<0x50, 5, 0x51, 0x52, 0xFF, 0>>
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state1, nil} = Model.apply(state0, cmd0)
    ^res0 = Response.pack(cmd0, nil)
    {nil, <<>>} = Response.parse(cmd0, res0)
  end

end
