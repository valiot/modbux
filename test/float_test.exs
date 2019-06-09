defmodule FloatTest do
  use ExUnit.Case
  alias Modbus.IEEE754

  # https://www.h-schmidt.net/FloatConverter/IEEE754.html
  # endianess tested agains opto22 analog modules
  test "float convertion test" do
    assert [0xC0A0, 0x0000] == IEEE754.to_2_regs(-5.0, :be)
    assert [0x0000, 0xC0A0] == IEEE754.to_2_regs(-5.0, :le)
    assert [0x40A0, 0x0000] == IEEE754.to_2_regs(+5.0, :be)
    assert [0x0000, 0x40A0] == IEEE754.to_2_regs(+5.0, :le)
    assert [0xC0A0, 0x0000, 0x40A0, 0x0000] == IEEE754.to_2n_regs([-5.0, +5.0], :be)
    assert [0x0000, 0xC0A0, 0x0000, 0x40A0] == IEEE754.to_2n_regs([-5.0, +5.0], :le)
    assert -5.0 == IEEE754.from_2_regs(0xC0A0, 0x0000, :be)
    assert -5.0 == IEEE754.from_2_regs(0x0000, 0xC0A0, :le)
    assert -5.0 == IEEE754.from_2_regs([0xC0A0, 0x0000], :be)
    assert -5.0 == IEEE754.from_2_regs([0x0000, 0xC0A0], :le)
    assert +5.0 == IEEE754.from_2_regs(0x40A0, 0x0000, :be)
    assert +5.0 == IEEE754.from_2_regs(0x0000, 0x40A0, :le)
    assert +5.0 == IEEE754.from_2_regs([0x40A0, 0x0000], :be)
    assert +5.0 == IEEE754.from_2_regs([0x0000, 0x40A0], :le)
    assert [-5.0, +5.0] == IEEE754.from_2n_regs([0xC0A0, 0x0000, 0x40A0, 0x0000], :be)
    assert [-5.0, +5.0] == IEEE754.from_2n_regs([0x0000, 0xC0A0, 0x0000, 0x40A0], :le)
  end
end
