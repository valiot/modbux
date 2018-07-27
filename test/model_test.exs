defmodule ModelTest do
  use ExUnit.Case
  alias Modbus.Model
  @state %{ 0x50=>%{ {:c, 0x5152}=>0, {:c, 0x5153}=>0, {:c, 0x5155}=>0 } }

  test "invalid slave" do
    assert false == Model.check_request(@state,  {81, :c, 20818, 1})
  end

  test "invalid address" do
    assert false == Model.check_request(@state,  {80, :c, 20830, 1})
  end

  test "invalid address (# bytes to read)" do
    assert false == Model.check_request(@state,  {80, :c, 20818, 3})
  end

  test "iligal function" do
    assert false == Model.check_request(@state,  {80, :fc, 20818, 1})
  end

  test "valid slave, function, address and number of bytes" do
    assert true == Model.check_request(@state,  {80, :c, 20818, 2})
    assert true == Model.check_request(@state,  {80, :c, 20821, 1})
  end
end
