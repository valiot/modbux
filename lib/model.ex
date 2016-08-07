defmodule Modbus.Model do

  def apply(state, {:rdo, slave, address, count}) do
    reads(state, {slave, :do, address, count})
  end

  def apply(state, {:rdi, slave, address, count}) do
    reads(state, {slave, :di, address, count})
  end

  def apply(state, {:rao, slave, address, count}) do
    reads(state, {slave, :ao, address, count})
  end

  def apply(state, {:rai, slave, address, count}) do
    reads(state, {slave, :ai, address, count})
  end

  def apply(state, {:wdo, slave, address, value}) when is_integer(value) do
    write(state, {slave, :do, address, value})
  end

  def apply(state, {:wdo, slave, address, values}) when is_list(values) do
    writes(state, {slave, :do, address, values})
  end

  def apply(state, {:wao, slave, address, value}) when is_integer(value) do
    write(state, {slave, :ao, address, value})
  end

  def apply(state, {:wao, slave, address, values}) when is_list(values) do
    writes(state, {slave, :ao, address, values})
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
