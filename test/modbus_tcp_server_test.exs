defmodule ModbusTcpServerTest do
  use ExUnit.Case
  alias Modbus.Tcp.Server
  alias Modbus.Tcp.Client

  setup do
    RingLogger.attach()
  end

  test "Server (connection, stop, configuration)" do
    model = %{80 => %{{:c, 20818} => 0, {:c, 20819} => 1, {:hr, 20817} => 0}}
    {:ok, _spid} = Server.start_link(model: model, port: 2000)
    {:ok, cpid} = Client.start_link(ip: {127, 0, 0, 1}, tcp_port: 3000)
    state_cpid = Client.state(cpid)
    assert state_cpid != Client.configure(cpid, tcp_port: 2000)
    assert :ok == Client.connect(cpid)
    Modbus.Tcp.Client.request(cpid, {:rc, 0x50, 20818, 2})
    assert Modbus.Tcp.Client.confirmation(cpid) == {:ok, [0, 1]}
    Modbus.Tcp.Client.request(cpid, {:rhr, 0x50, 20817, 1})
    assert Modbus.Tcp.Client.confirmation(cpid) == {:ok, [0]}
    Modbus.Tcp.Client.request(cpid, {:phr, 0x50, 20817, [1, 1]})
    assert Modbus.Tcp.Client.confirmation(cpid) == :ok
    Modbus.Tcp.Client.request(cpid, {:rhr, 0x50, 20817, 2})
    assert Modbus.Tcp.Client.confirmation(cpid) == {:ok, [1, 1]}
    Modbus.Tcp.Client.request(cpid, {:rhr, 0x50, 20818, 1})
    assert Modbus.Tcp.Client.confirmation(cpid) == {:ok, [1]}
    assert :error == Client.configure(cpid, active: false)
    assert :ok == Client.close(cpid)
    assert :ok == Client.stop(cpid)
    refute_received {:modbus_tcp, {:server_request, {:rc, 0x50, 20818, 2}}}
  end

  test "Server close active ports" do
    :gen_tcp.listen(2000, [:binary, packet: :raw, active: true, reuseaddr: true])
    model = %{0x50 => %{{:c, 0x5152} => 0}}
    {:ok, s_pid} = Server.start_link(model: model, port: 2000)
    assert Process.alive?(s_pid)
  end

  test "Server notifies an DB update" do
    model = %{0x50 => %{{:c, 0x5152} => 0}}
    {:ok, _spid} = Server.start_link(model: model, port: 2001, active: true)
    {:ok, c_pid} = Client.start_link(ip: {127, 0, 0, 1}, tcp_port: 2001)
    Client.connect(c_pid)
    Modbus.Tcp.Client.request(c_pid, {:rc, 0x50, 0x5152, 1})
    assert Modbus.Tcp.Client.confirmation(c_pid) == {:ok, [0]}
    assert_received {:modbus_tcp, {:server_request, {:rc, 80, 20818, 1}}}
  end

  test "DB updates from Elixir" do
    model = %{0x50 => %{{:c, 0x5152} => 0}}
    {:ok, s_pid} = Server.start_link(model: model, port: 2002, active: true)
    assert Server.update(s_pid, {:fc, 0x50, 0x5152, 1}) == :ok
    assert Server.get_db(s_pid) == %{80 => %{{:c, 20818} => 1}}
    refute_received {:modbus_tcp, {:server_request, {:rc, 80, 20818, 1}}}
  end
end
