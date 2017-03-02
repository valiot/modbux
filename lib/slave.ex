defmodule Modbus.Tcp.Slave do
  @moduledoc false
  import Supervisor.Spec
  alias Modbus.Model.Shared
  alias Modbus.Tcp

  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  def stop(pid) do
    Agent.stop(pid)
  end

  #comply with formward id
  def id(pid) do
    Agent.get(pid, fn %{ip: ip, port: port, name: name} -> {:ok, %{ip: ip, port: port, name: name}} end)
  end

  def state(pid) do
    Agent.get(pid, fn state -> state end)
  end

  defp init(params) do
    model = Keyword.fetch!(params, :model)
    {:ok, shared} = Shared.start_link([model: model])
    remote = Keyword.get(params, :remote, false)
    ip = if remote, do: {0,0,0,0}, else: {127,0,0,1}
    {:ok, listener} = :gen_tcp.listen(0, [:binary, ip: ip,
      packet: :raw, active: false])
    {:ok, {ip, port}} = :inet.sockname(listener)
    name = Keyword.get(params, :name, name(ip, port))
    spec = worker(__MODULE__, [], restart: :temporary, function: :start_child)
    {:ok, sup} = Supervisor.start_link([spec], strategy: :simple_one_for_one)
    accept = spawn_link(fn -> accept(listener, sup, shared) end)
    %{ip: ip, port: port, name: name, shared: shared, sup: sup, accept: accept, listener: listener}
  end

  defp name(ip, port) do
    ips = :inet_parse.ntoa(ip)
    mod = Atom.to_string(__MODULE__)
    "#{mod}:#{ips}:#{port}"
  end

  defp accept(listener, sup, model) do
    {:ok, socket} = :gen_tcp.accept(listener)
    {:ok, pid} = Supervisor.start_child(sup, [socket, model])
    :ok = :gen_tcp.controlling_process(socket, pid)
    send pid, :go
    accept(listener, sup, model)
  end

  def start_child(socket, shared) do
    {:ok, spawn_link(fn ->
      receive do
        :go ->
          loop(socket, shared)
      end
    end)}
  end

  defp loop(socket, shared) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    {cmd, transid} = Tcp.parse_req(data)
    {:ok, values} = Shared.apply(shared, cmd)
    resp = Tcp.pack_res(cmd, values, transid)
    :ok = :gen_tcp.send(socket, resp)
    loop(socket, shared)
  end
end
