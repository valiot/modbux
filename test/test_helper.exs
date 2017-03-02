ExUnit.start()

defmodule Modbus.Slave do
  import Supervisor.Spec
  alias Modbus.Model
  alias Modbus.Tcp

  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  def stop(pid) do
    Agent.stop(pid)
  end

  def id(pid) do
    Agent.get(pid, fn %{ip: ip, port: port, model: model} -> {:ok, %{ip: ip, port: port, model: model}} end)
  end

  def state(pid) do
    Agent.get(pid, fn state -> state end)
  end

  defp init(params) do
    model = Keyword.fetch!(params, :model)
    remote = Keyword.get(params, :remote, false)
    ip = if remote, do: {0,0,0,0}, else: {127,0,0,1}
    {:ok, listener} = :gen_tcp.listen(0, [:binary, ip: ip,
      packet: :raw, active: false])
    {:ok, {ip, port}} = :inet.sockname(listener)
    spec = worker(__MODULE__, [], restart: :temporary, function: :start_child)
    {:ok, sup} = Supervisor.start_link([spec], strategy: :simple_one_for_one)
    accept = spawn_link(fn -> accept(listener, sup, model) end)
    %{ip: ip, port: port, model: model, sup: sup, accept: accept, listener: listener}
  end

  defp accept(listener, sup, model) do
    {:ok, socket} = :gen_tcp.accept(listener)
    {:ok, pid} = Supervisor.start_child(sup, [socket, model])
    :ok = :gen_tcp.controlling_process(socket, pid)
    send pid, :go
    accept(listener, sup, model)
  end

  def start_child(socket, model) do
    {:ok, spawn_link(fn ->
      receive do
        :go ->
          loop(socket, model)
      end
    end)}
  end

  defp loop(socket, model) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    {cmd, transid} = Tcp.parse_req(data)
    {model2, values} = Model.apply(model, cmd)
    resp = Tcp.pack_res(cmd, values, transid)
    :ok = :gen_tcp.send(socket, resp)
    loop(socket, model2)
  end
end

defmodule TestHelper do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model
  alias Modbus.Rtu
  alias Modbus.Tcp
  alias Modbus.Master
  alias Modbus.Slave

  def pp1(cmd, req, res, val, state) do
    assert req == Request.pack(cmd)
    assert cmd == Request.parse(req)
    assert {state, val} == Model.apply(state, cmd)
    assert res == Response.pack(cmd, val)
    assert val == Response.parse(cmd, res)
    #length predition
    assert byte_size(res) == Response.length(cmd)
    #rtu
    rtu_req = Rtu.pack_req(cmd)
    assert cmd == Rtu.parse_req(rtu_req)
    rtu_res = Rtu.pack_res(cmd, val)
    assert val == Rtu.parse_res(cmd, rtu_res)
    assert byte_size(rtu_res) == Rtu.res_len(cmd)
    #tcp
    tcp_req = Tcp.pack_req(cmd, 1)
    assert {cmd, 1} == Tcp.parse_req(tcp_req)
    tcp_res = Tcp.pack_res(cmd, val, 1)
    assert val == Tcp.parse_res(cmd, tcp_res, 1)
    assert byte_size(tcp_res) == Tcp.res_len(cmd)
    #master
    {:ok, slave_pid} = Slave.start_link([model: state])
    {:ok, %{port: port}} =  Slave.id(slave_pid)
    {:ok, master_pid} = Master.start_link([port: port, ip: {127,0,0,1}])
    assert {:ok, val} == Master.tcp(master_pid, cmd)
  end

  def pp2(cmd, req, res, state0, state1) do
    assert req == Request.pack(cmd)
    assert cmd == Request.parse(req)
    assert {state1, nil} == Model.apply(state0, cmd)
    assert res == Response.pack(cmd, nil)
    assert nil == Response.parse(cmd, res)
    #length predition
    assert byte_size(res) == Response.length(cmd)
    #rtu
    rtu_req = Rtu.pack_req(cmd)
    assert cmd == Rtu.parse_req(rtu_req)
    rtu_res = Rtu.pack_res(cmd, nil)
    assert nil == Rtu.parse_res(cmd, rtu_res)
    assert byte_size(rtu_res) == Rtu.res_len(cmd)
    #tcp
    tcp_req = Tcp.pack_req(cmd, 1)
    assert {cmd, 1} == Tcp.parse_req(tcp_req)
    tcp_res = Tcp.pack_res(cmd, nil, 1)
    assert nil == Tcp.parse_res(cmd, tcp_res, 1)
    assert byte_size(tcp_res) == Tcp.res_len(cmd)
    #master
    {:ok, slave_pid} = Slave.start_link([model: state0])
    {:ok, %{port: port}} =  Slave.id(slave_pid)
    {:ok, master_pid} = Master.start_link([port: port, ip: {127,0,0,1}])
    assert :ok == Master.tcp(master_pid, cmd)
  end

end
