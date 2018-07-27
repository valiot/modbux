defmodule ModbusTcpTest do
  use ExUnit.Case
  test "test Slave and Master desconexión" do
    #run with: mix slave
    alias Modbus.Tcp.Slave
    alias Modbus.Tcp.Master

    #start your slave with a shared model
    model = %{ 0x50=>%{ {:c, 0x5152}=>0 } }
    {:ok, spid} = Slave.start_link([model: model])
    #get the assigned tcp port
    {:ok, %{port: port}} = Slave.id(spid)

    #interact with it
    {:ok, mpid} = Master.start_link([ip: {127,0,0,1}, port: port])
    assert {:ok, [0]} == Master.exec(mpid, {:rc, 0x50, 0x5152, 1})
  end

  #  test "test Master for independent Slave" do
  #    alias Modbus.Tcp.Master
  #    RingLogger.attach
  #    {:ok, mpid} = Master.start_link([ip: {127,0,0,1}, port: port])
  #    {:ok, [0]} = Master.exec(mpid, {:rc, 0x50, 0x5153, 1})
  #  end
end
