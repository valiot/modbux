defmodule ModbuxTcpClientTest do
  use ExUnit.Case
  alias Modbux.Tcp
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
    {:ok, cpid} = Client.start_link(ip: {127, 0, 0, 1}, tcp_port: 50123)
    assert {:error, :econnrefused} == Client.connect(cpid)
    assert {:error, :closed} == Client.close(cpid)
  end

  # https://github.com/valiot/modbux/issues/14
  test "client handles two responses in a single tcp packet" do
    {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false])
    {:ok, port} = :inet.port(listen_socket)

    {:ok, cpid} = Client.start_link(ip: {127, 0, 0, 1}, tcp_port: port, active: true)
    assert :ok == Client.connect(cpid)
    {:ok, server_socket} = :gen_tcp.accept(listen_socket)

    coils = [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
    assert :ok == Client.request(cpid, {:ri, 0, 0, 16})
    assert :ok == Client.request(cpid, {:fc, 0, 16, 1})

    # Both responses (transid 0 and 1) arrive in the same tcp packet.
    response = Tcp.pack_res({:ri, 0, 0, 16}, coils, 0) <> Tcp.pack_res({:fc, 0, 16, 1}, nil, 1)
    :ok = :gen_tcp.send(server_socket, response)

    assert_receive {:modbus_tcp, {:ri, 0, 0, 16}, ^coils}, 1000
    assert_receive {:modbus_tcp, {:fc, 0, 16, 1}, nil}, 1000

    assert :ok == Client.stop(cpid)
    :gen_tcp.close(server_socket)
    :gen_tcp.close(listen_socket)
  end
end
