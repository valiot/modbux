defmodule F04Test do
  use ExUnit.Case
  import TestHelper

  test "Read 0x6162 from Single Input Register" do
    model0 = %{ 0x50=>%{ {:ir, 0x5152}=>0x6162 } }
    cmd0 = {:rir, 0x50, 0x5152, 1}
    req0 = <<0x50, 4, 0x51, 0x52, 0, 1>>
    res0 = <<0x50, 4, 2, 0x61, 0x62>>
    val0 = [0x6162]
    pp1 cmd0, req0, res0, val0, model0
  end

  test "Read 0x616263646566 from Multiple Input Registers" do
    model0 = %{ 0x50=>%{
      {:ir, 0x5152}=>0x6162, {:ir, 0x5153}=>0x6364, {:ir, 0x5154}=>0x6566,
    } }
    cmd0 = {:rir, 0x50, 0x5152, 3}
    req0 = <<0x50, 4, 0x51, 0x52, 0, 3>>
    res0 = <<0x50, 4, 6, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66>>
    val0 = [0x6162,0x6364,0x6566]
    pp1 cmd0, req0, res0, val0, model0
  end

end
