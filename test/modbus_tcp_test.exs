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

   test "test Client (connection, stop, configuration)" do
     alias Modbus.Tcp.Slave
     alias Modbus.Tcp.Client
     RingLogger.attach
     model = %{80 => %{{:c, 20818} => 0, {:c, 20819} => 1, {:hr, 20817} => 0}}
     {:ok, spid} = Slave.start_link([model: model, port: 2000])
     {:ok, cpid} = Client.start_link([ip: {127,0,0,1}, port: 3000])
     state_cpid = Client.state(cpid)
     assert state_cpid != Client.configure(cpid, [port: 2000])
     assert :ok == Client.connect(cpid)
     assert :error == Client.configure(cpid, [active: false])
     assert :ok == Client.close(cpid)
     assert :ok == Client.stop(cpid)
   end

   test "test Client errors" do
    alias Modbus.Tcp.Slave
    alias Modbus.Tcp.Client
    RingLogger.attach
    {:ok, cpid} = Client.start_link([ip: {127,0,0,1}, port: 5000])
    assert {:error, :econnrefused} == Client.connect(cpid)
    assert {:error, :closed} == Client.close(cpid)
  end
end
