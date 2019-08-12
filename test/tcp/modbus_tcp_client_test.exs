defmodule ModbuxTcpClientTest do
  use ExUnit.Case
  alias Modbux.Tcp.{Client, Server}

  test "test Client (connection, stop, configuration)" do
    model = %{80 => %{{:c, 20818} => 0, {:c, 20819} => 1, {:hr, 20817} => 0}}
    {:ok, _spid} = Server.start_link(model: model, port: 2000)
    {:ok, cpid} = Client.start_link(ip: {127, 0, 0, 1}, tcp_port: 3000)
    state_cpid = Client.state(cpid)
    assert state_cpid != Client.configure(cpid, tcp_port: 2000)
    assert :ok == Client.connect(cpid)
    assert :error == Client.configure(cpid, active: false)
    assert :ok == Client.close(cpid)
    assert :ok == Client.stop(cpid)
  end

  test "test Client errors" do
    {:ok, cpid} = Client.start_link(ip: {127, 0, 0, 1}, port: 5000)
    assert {:error, :econnrefused} == Client.connect(cpid)
    assert {:error, :closed} == Client.close(cpid)
  end
end
