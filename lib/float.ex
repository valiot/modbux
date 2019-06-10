defmodule Modbus.IEEE754 do
  @moduledoc """
  IEEE754 float helper

  Based on https://www.h-schmidt.net/FloatConverter/IEEE754.html.
  """

  @doc """
  Converts a couple of 16-bit registers to IEEE754 float.

  ## Example

  ```elixir
  +5.0 = IEEE754.from_2_regs(0x40a0, 0x0000, :be)
  ```
  """
  def from_2_regs(w0, w1, :be) do
    <<value::float-32>> = <<w0::16, w1::16>>
    value
  end

  def from_2_regs(w0, w1, :le) do
    <<value::float-32>> = <<w1::16, w0::16>>
    value
  end

  @doc """
  Converts a couple of 16-bit registers to IEEE754 float.

  ## Example

  ```elixir
  +5.0 = IEEE754.from_2_regs(0x40a0, 0x0000, :be)
  ```
  """
  def from_2_regs([w0, w1], :be) do
    <<f::float-32>> = <<w0::16, w1::16>>
    f
  end

  def from_2_regs([w0, w1], :le) do
    <<f::float-32>> = <<w1::16, w0::16>>
    f
  end

  @doc """
  Converts a list of 2n 16-bit registers to a IEEE754 floats list.

  ## Example

  ```elixir
  [-5.0, +5.0] = IEEE754.from_2n_regs([0xc0a0, 0x0000, 0x40a0, 0x0000], :be)
  ```
  """
  def from_2n_regs([], _), do: []

  def from_2n_regs([w0, w1 | tail], endianness) do
    [from_2_regs(w0, w1, endianness) | from_2n_regs(tail, endianness)]
  end

  @doc """
  Converts a IEEE754 float to a couple of 16-bit registers.

  ## Example

  ```elixir
  [0xc0a0, 0x0000] = IEEE754.to_2_regs(-5.0)
  ```
  """
  def to_2_regs(f, :be) do
    <<w0::16, w1::16>> = <<f::float-32>>
    [w0, w1]
  end

  def to_2_regs(f, :le) do
    <<w0::16, w1::16>> = <<f::float-32>>
    [w1, w0]
  end

  @doc """
  Converts a list of IEEE754 floats to a list of 2n 16-bit registers.

  ## Example

  ```elixir
  [0xc0a0, 0x0000, 0x40a0, 0x0000] = IEEE754.to_2n_regs([-5.0, +5.0])
  ```
  """
  def to_2n_regs([], _), do: []

  def to_2n_regs([f | tail], endianness) do
    [w0, w1] = to_2_regs(f, endianness)
    [w0, w1 | to_2n_regs(tail, endianness)]
  end
end
