defmodule ModbusTcpServerTest do
  use ExUnit.Case
  alias Modbus.Tcp.Server
  alias Modbus.Tcp.Client

  setup do
    RingLogger.attach
  end

  test "Server (connection, stop, configuration)" do
    model = %{80 => %{{:c, 20818} => 0, {:c, 20819} => 1, {:hr, 20817} => 0}}
    {:ok, spid} = Server.start_link([model: model, port: 2000])
    {:ok, cpid} = Client.start_link([ip: {127,0,0,1}, tcp_port: 3000])
    state_cpid = Client.state(cpid)
    assert state_cpid != Client.configure(cpid, [tcp_port: 2000])
    assert :ok == Client.connect(cpid)
    Modbus.Tcp.Client.request(cpid, {:rc, 0x50, 20818, 2})
    assert Modbus.Tcp.Client.confirmation(cpid) == {:ok, [0,1]}
    Modbus.Tcp.Client.request(cpid, {:rhr, 0x50, 20817, 1})
    assert Modbus.Tcp.Client.confirmation(cpid) == {:ok, [0]}
    assert :error == Client.configure(cpid, [active: false])
    assert :ok == Client.close(cpid)
    assert :ok == Client.stop(cpid)
  end

  test "Server close active ports" do
    :gen_tcp.listen(2000, [:binary, packet: :raw, active: true, reuseaddr: true])
    model = %{ 0x50=>%{ {:c, 0x5152}=>0 }}
    {:ok, s_pid} = Server.start_link([model: model, port: 2000])
    assert Process.alive?(s_pid)
  end
end
