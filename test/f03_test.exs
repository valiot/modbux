defmodule F03Test do
  use ExUnit.Case
  import TestHelper

  test "Read 0x6162 from Single Holding Register" do
    state0 = %{ 0x50=>%{ {:hr, 0x5152}=>0x6162 } }
    cmd0 = {:rhr, 0x50, 0x5152, 1}
    req0 = <<0x50, 3, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 3, 2, 0x61, 0x62>>
    val0 = [0x6162]
    pp1 cmd0, req0, res0, val0, state0
  end

  test "Read 0x616263646566 from Multiple Holding Registers" do
    state0 = %{ 0x50=>%{
      {:hr, 0x5152}=>0x6162, {:hr, 0x5153}=>0x6364, {:hr, 0x5154}=>0x6566,
    } }
    cmd0 = {:rhr, 0x50, 0x5152, 3}
    req0 = <<0x50, 3, 0x51, 0x52, 0, 3>>
    res0 = <<0x50, 3, 6, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66>>
    val0 = [0x6162,0x6364,0x6566]
    pp1 cmd0, req0, res0, val0, state0
  end

end
