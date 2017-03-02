defmodule F06Test do
  use ExUnit.Case
  import TestHelper

  test "Write 0x6162 to Single Holding Register" do
    state0 = %{ 0x50=>%{ {:hr, 0x5152}=>0 } }
    state1 = %{ 0x50=>%{ {:hr, 0x5152}=>0x6162 } }
    val0 = 0x6162
    cmd0 = {:phr, 0x50, 0x5152, val0}
    req0 = <<0x50, 6, 0x51, 0x52, 0x61, 0x62>>
    res0 = <<0x50, 6, 0x51, 0x52, 0x61, 0x62>>
    pp2 cmd0, req0, res0, state0, state1
  end

end
