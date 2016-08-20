defmodule F1Test do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model

  test "Read 0 from Single Digital Output" do
    state0 = %{ 0x50=>%{ {:hr, 0x5152}=>0 } }
    cmd0 = {:rc, 0x50, 0x5152, 1}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 1, 1, 0x00>>
    val0 = [0]
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state0, ^val0} = Model.apply(state0, cmd0)
    ^res0 = Response.pack(cmd0, val0)
    {^val0, <<>>} = Response.parse(cmd0, res0)
  end

  test "Read 1 from Single Digital Output" do
    state0 = %{ 0x50=>%{ {:hr, 0x5152}=>1 } }
    cmd0 = {:rc, 0x50, 0x5152, 1}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 1, 1, 0x01>>
    val0 = [1]
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state0, ^val0} = Model.apply(state0, cmd0)
    ^res0 = Response.pack(cmd0, val0)
    {^val0, <<>>} = Response.parse(cmd0, res0)
  end

  test "Read 011 from Multiple Digital Outputs" do
    state0 = %{ 0x50=>%{
      {:hr, 0x5152}=>0, {:hr, 0x5153}=>1, {:hr, 0x5154}=>1,
    } }
    cmd0 = {:rc, 0x50, 0x5152, 3}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 3>>
    res0 = <<0x50, 1, 1, 0x06>>
    val0 = [0,1,1]
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state0, ^val0} = Model.apply(state0, cmd0)
    ^res0 = Response.pack(cmd0, val0)
    {^val0, <<>>} = Response.parse(cmd0, res0)
  end

  test "Read 0011 1100 0101 from Multiple Digital Outputs" do
    state0 = %{ 0x50=>%{
      {:hr, 0x5152}=>0, {:hr, 0x5153}=>0, {:hr, 0x5154}=>1, {:hr, 0x5155}=>1,
      {:hr, 0x5156}=>1, {:hr, 0x5157}=>1, {:hr, 0x5158}=>0, {:hr, 0x5159}=>0,
      {:hr, 0x515A}=>0, {:hr, 0x515B}=>1, {:hr, 0x515C}=>0, {:hr, 0x515D}=>1,
    } }
    cmd0 = {:rc, 0x50, 0x5152, 12}
    req0 = <<0x50, 1, 0x51, 0x52, 0, 12>>
    res0 = <<0x50, 1, 2, 0x3C, 0x0A>>
    val0 = [0,0,1,1, 1,1,0,0, 0,1,0,1]
    ^req0 = Request.pack(cmd0)
    {^cmd0, <<>>} = Request.parse(req0)
    {^state0, ^val0} = Model.apply(state0, cmd0)
    ^res0 = Response.pack(cmd0, val0)
    {^val0, <<>>} = Response.parse(cmd0, res0)
  end

end
