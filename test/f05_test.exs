defmodule F05Test do
  use ExUnit.Case
  import TestHelper

  test "Write 0 to Single Coil" do
    state0 = %{ 0x50=>%{ {:c, 0x5152}=>1 } }
    state1 = %{ 0x50=>%{ {:c, 0x5152}=>0 } }
    val0 = 0
    cmd0 = {:fc, 0x50, 0x5152, val0}
    req0 = <<0x50, 5, 0x51, 0x52, 0, 0>>
    res0 = <<0x50, 5, 0x51, 0x52, 0, 0>>
    pp2 cmd0, req0, res0, state0, state1
  end

  test "Write 1 to Single Coil" do
    state0 = %{ 0x50=>%{ {:c, 0x5152}=>0 } }
    state1 = %{ 0x50=>%{ {:c, 0x5152}=>1 } }
    val0 = 1
    cmd0 = {:fc, 0x50, 0x5152, val0}
    req0 = <<0x50, 5, 0x51, 0x52, 0xFF, 0>>
    res0 = <<0x50, 5, 0x51, 0x52, 0xFF, 0>>
    pp2 cmd0, req0, res0, state0, state1
  end

end
