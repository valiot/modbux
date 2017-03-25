defmodule Modbus.IEEE754 do
  @moduledoc """
  IEEE754 float helper

  Based on https://www.h-schmidt.net/FloatConverter/IEEE754.html.
  """

  @doc """
  Converts a couple of 16-bit registers to IEEE754 float.

  ## Example

  ```elixir
  +5.0 = IEEE754.from_2_regs(0x40a0, 0x0000)
  ```
  """
  def from_2_regs(w0, w1) do
    <<value::float-32>> = <<w0::16, w1::16>>
    value
  end

  @doc """
  Converts a couple of 16-bit registers to IEEE754 float.

  ## Example

  ```elixir
  +5.0 = IEEE754.from_2_regs(0x40a0, 0x0000)
  ```
  """
  def from_2_regs([w0, w1]) do
    <<f::float-32>> = <<w0::16, w1::16>>
    f
  end


  @doc """
  Converts a list of 2n 16-bit registers to a IEEE754 floats list.

  ## Example

  ```elixir
  [-5.0, +5.0] = IEEE754.from_2n_regs([0xc0a0, 0x0000, 0x40a0, 0x0000])
  ```
  """
  def from_2n_regs([]), do: []
  def from_2n_regs([w0, w1 | tail]) do
    [from_2_regs(w0, w1) | from_2n_regs(tail)]
  end

  @doc """
  Converts a IEEE754 float to a couple of 16-bit registers.

  ## Example

  ```elixir
  [0xc0a0, 0x0000] = IEEE754.to_2_regs(-5.0)
  ```
  """
  def to_2_regs(f) do
    <<w0::16, w1::16>> = <<f::float-32>>
    [w0, w1]
  end

  @doc """
  Converts a list of IEEE754 floats to a list of 2n 16-bit registers.

  ## Example

  ```elixir
  [0xc0a0, 0x0000, 0x40a0, 0x0000] = IEEE754.to_2n_regs([-5.0, +5.0])
  ```
  """
  def to_2n_regs([]), do: []
  def to_2n_regs([f | tail]) do
    [w0, w1] = to_2_regs(f)
    [w0, w1 | to_2n_regs(tail)]
  end

end
