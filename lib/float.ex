defmodule Modbus.IEEE754 do

  def from_2_regs(w0, w1) do
    <<value::float-32>> = <<w0::16, w1::16>>
    value
  end

  def from_2_regs([w0, w1]) do
    <<f::float-32>> = <<w0::16, w1::16>>
    f
  end

  def from_2n_regs([]), do: []
  def from_2n_regs([w0, w1 | tail]) do
    [from_2_regs(w0, w1) | from_2n_regs(tail)]
  end

  def to_2_regs(f) do
    <<w0::16, w1::16>> = <<f::float-32>>
    [w0, w1]
  end

  def to_2n_regs([]), do: []
  def to_2n_regs([f | tail]) do
    [w0, w1] = to_2_regs(f)
    [w0, w1 | to_2n_regs(tail)]
  end

end
