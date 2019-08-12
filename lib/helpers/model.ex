defmodule Modbux.Model do
  @moduledoc """
  Model helper, functions to write and read the Slave/Server DB.
  """
  require Logger

  def apply(state, {:rc, slave, address, count}) do
    reads(state, {slave, :c, address, count})
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
    write(state, {slave, :c, address, value})
  end

  def apply(state, {:fc, slave, address, values}) when is_list(values) do
    writes(state, {slave, :c, address, values})
  end

  def apply(state, {:phr, slave, address, value}) when is_integer(value) do
    write(state, {slave, :hr, address, value})
  end

  def apply(state, {:phr, slave, address, values}) when is_list(values) do
    writes(state, {slave, :hr, address, values})
  end

  # Error and exception clause
  def apply(state, _cmd) do
    # do nothing
    {nil, state}
  end

  @spec reads(map, {any, any, any, any}) :: {nil | {:error, :eaddr} | {:ok, [any]}, map}
  def reads(state, {slave, type, address, count}) do
    # checks the slave_ids
    if Map.has_key?(state, slave) do
      try do
        map = Map.fetch!(state, slave)

        list =
          for point <- address..(address + count - 1) do
            Map.fetch!(map, {type, point})
          end

        {{:ok, list}, state}
      rescue
        _error ->
          {{:error, :eaddr}, state}
      end
    else
      # is a different slave id, do nothing.
      {nil, state}
    end
  end

  @spec write(map, {any, any, any, any}) :: {nil | {:error, :eaddr} | {:ok, nil}, map}
  def write(state, {slave, type, address, value}) do
    # checks the slave_ids
    if Map.has_key?(state, slave) do
      try do
        cmap = Map.fetch!(state, slave)
        nmap = Map.replace!(cmap, {type, address}, value)
        {{:ok, nil}, Map.put(state, slave, nmap)}
      rescue
        _error ->
          {{:error, :eaddr}, state}
      end
    else
      # is a different slave id, do nothing.
      {nil, state}
    end
  end

  def writes(state, {slave, type, address, values}) do
    # checks the slave_ids
    if Map.has_key?(state, slave) do
      try do
        cmap = Map.fetch!(state, slave)
        final = address + Enum.count(values)

        {^final, nmap} =
          Enum.reduce(values, {address, cmap}, fn value, {i, map} ->
            {i + 1, Map.replace!(map, {type, i}, value)}
          end)

        {{:ok, nil}, Map.put(state, slave, nmap)}
      rescue
        _error ->
          {{:error, :eaddr}, state}
      end
    else
      # is a different slave id, do nothing.
      {nil, state}
    end
  end
end
