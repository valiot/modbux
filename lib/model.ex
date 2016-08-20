defmodule Modbus.Model do
  @moduledoc false

  def apply(state, {:rc, slave, address, count}) do
    reads(state, {slave, :hr, address, count})
  end

  def apply(state, {:ri, slave, address, count}) do
    reads(state, {slave, :i, address, count})
  end

  def apply(state, {:rhr, slave, address, count}) do
    reads(state, {slave, :hr, address, count})
  end

  def apply(state, {:rir, slave, address, count}) do
    reads(state, {slave, :ir, address, count})
  end

  def apply(state, {:fc, slave, address, value}) when is_integer(value) do
    write(state, {slave, :hr, address, value})
  end

  def apply(state, {:fc, slave, address, values}) when is_list(values) do
    writes(state, {slave, :hr, address, values})
  end

  def apply(state, {:phr, slave, address, value}) when is_integer(value) do
    write(state, {slave, :hr, address, value})
  end

  def apply(state, {:phr, slave, address, values}) when is_list(values) do
    writes(state, {slave, :hr, address, values})
  end

  defp reads(state, {slave, type, address, count}) do
    cmap = Map.fetch!(state, slave)
    list = for point <- address..address+count-1 do
      Map.fetch!(cmap, {type, point})
    end
    {state, list}
  end

  defp write(state, {slave, type, address, value}) do
    cmap = Map.fetch!(state, slave)
    nmap = Map.put(cmap, {type, address}, value)
    {Map.put(state, slave, nmap), nil}
  end

  defp writes(state, {slave, type, address, values}) do
    cmap = Map.fetch!(state, slave)
    final = address + Enum.count(values)
    {^final, nmap} = Enum.reduce(values, {address, cmap}, fn (value, {i, map}) ->
      {i+1, Map.put(map, {type, i}, value)}
    end)
    {Map.put(state, slave, nmap), nil}
  end

end
