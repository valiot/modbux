defmodule F02Test do
  use ExUnit.Case
  import TestHelper

  test "Read 0 from Single Input" do
    model0 = %{ 0x50=>%{ {:i, 0x5152}=>0 } }
    cmd0 = {:ri, 0x50, 0x5152, 1}
    req0 = <<0x50, 2, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 2, 1, 0x00>>
    val0 = [0]
    pp1 cmd0, req0, res0, val0, model0
  end

  test "Read 1 from Single Input" do
    model0 = %{ 0x50=>%{ {:i, 0x5152}=>1 } }
    cmd0 = {:ri, 0x50, 0x5152, 1}
    req0 = <<0x50, 2, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 2, 1, 0x01>>
    val0 = [1]
    pp1 cmd0, req0, res0, val0, model0
  end

  test "Read 011 from Multiple Inputs" do
    model0 = %{ 0x50=>%{
      {:i, 0x5152}=>0, {:i, 0x5153}=>1, {:i, 0x5154}=>1,
    } }
    cmd0 = {:ri, 0x50, 0x5152, 3}
    req0 = <<0x50, 2, 0x51, 0x52, 0, 3>>
    res0 = <<0x50, 2, 1, 0x06>>
    val0 = [0,1,1]
    pp1 cmd0, req0, res0, val0, model0
  end

  test "Read 0011 1100 0101 from Multiple Inputs" do
    model0 = %{ 0x50=>%{
      {:i, 0x5152}=>0, {:i, 0x5153}=>0, {:i, 0x5154}=>1, {:i, 0x5155}=>1,
      {:i, 0x5156}=>1, {:i, 0x5157}=>1, {:i, 0x5158}=>0, {:i, 0x5159}=>0,
      {:i, 0x515A}=>0, {:i, 0x515B}=>1, {:i, 0x515C}=>0, {:i, 0x515D}=>1,
    } }
    cmd0 = {:ri, 0x50, 0x5152, 12}
    req0 = <<0x50, 2, 0x51, 0x52, 0, 12>>
    res0 = <<0x50, 2, 2, 0x3C, 0x0A>>
    val0 = [0,0,1,1, 1,1,0,0, 0,1,0,1]
    pp1 cmd0, req0, res0, val0, model0
  end

end
