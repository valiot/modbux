defmodule ModelTest do
  use ExUnit.Case
  alias Modbux.Model
  @state %{0x50 => %{{:c, 0x5152} => 0, {:c, 0x5153} => 0, {:c, 0x5155} => 0}}

  test "invalid slave" do
    assert {nil, @state} == Model.reads(@state, {81, :c, 20818, 1})
    assert {nil, @state} == Model.write(@state, {81, :c, 20818, 1})
    assert {nil, @state} == Model.writes(@state, {81, :c, 20818, [1, 1]})
  end

  test "invalid address" do
    assert {{:error, :eaddr}, @state} == Model.reads(@state, {80, :c, 20830, 1})
    assert {{:error, :eaddr}, @state} == Model.write(@state, {80, :c, 20830, 1})
    assert {{:error, :eaddr}, @state} == Model.writes(@state, {80, :c, 20830, [1, 1]})
  end

  test "invalid address (# bytes to read)" do
    assert {{:error, :eaddr}, @state} == Model.reads(@state, {80, :c, 20818, 3})
    assert {{:error, :eaddr}, @state} == Model.writes(@state, {80, :c, 20818, [1, 1, 1]})
  end

  test "illegal function" do
    assert {{:error, :eaddr}, @state} == Model.reads(@state, {80, :fc, 20818, 1})
    assert {{:error, :eaddr}, @state} == Model.write(@state, {80, :fc, 20818, 1})
    assert {{:error, :eaddr}, @state} == Model.writes(@state, {80, :fc, 20818, [1, 1]})
  end

  test "valid slave, function, address and number of bytes" do
    assert {{:ok, [0]}, @state} == Model.reads(@state, {80, :c, 20818, 1})
    d_state = %{0x50 => %{{:c, 0x5152} => 1, {:c, 0x5153} => 0, {:c, 0x5155} => 0}}
    assert {{:ok, nil}, d_state} == Model.write(@state, {80, :c, 20818, 1})
    d_state = %{0x50 => %{{:c, 0x5152} => 1, {:c, 0x5153} => 1, {:c, 0x5155} => 0}}
    assert {{:ok, nil}, d_state} == Model.writes(@state, {80, :c, 20818, [1, 1]})
  end
end
