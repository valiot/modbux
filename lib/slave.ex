defmodule Modbus.Tcp.Slave do
  @moduledoc false
  import Supervisor.Spec
  alias Modbus.Model.Shared
  alias Modbus.Tcp
  require Logger

  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  def stop(pid) do
    Agent.stop(pid)
  end

  # comply with formward id
  def id(pid) do
    case state(pid) do
      {:error, reason} ->
        {:error, reason}

      _ ->
        Agent.get(pid, fn %{ip: ip, port: port, name: name} -> {:ok, %{ip: ip, port: port, name: name}} end)
    end
  end

  def state(pid) do
    Agent.get(pid, fn state -> state end)
  end

  defp init(params) do
    model = Keyword.fetch!(params, :model)
    {:ok, shared} = Shared.start_link(model: model)
    port = Keyword.get(params, :port, 0)

    case :gen_tcp.listen(port, [:binary, packet: :raw, active: false]) do
      {:ok, listener} ->
        {:ok, {ip, port}} = :inet.sockname(listener)
        name = Keyword.get(params, :name, name(ip, port))
        spec = worker(__MODULE__, [], restart: :temporary, function: :start_child)
        {:ok, sup} = Supervisor.start_link([spec], strategy: :simple_one_for_one)
        accept = spawn_link(fn -> accept(listener, sup, shared) end)
        %{ip: ip, port: port, name: name, shared: shared, sup: sup, accept: accept, listener: listener}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp name(ip, port) do
    ips = :inet_parse.ntoa(ip)
    mod = Atom.to_string(__MODULE__)
    "#{mod}:#{ips}:#{port}"
  end

  defp accept(listener, sup, model) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        Logger.debug("New Client")
        {:ok, pid} = Supervisor.start_child(sup, [socket, model])
        :ok = :gen_tcp.controlling_process(socket, pid)
        send(pid, :go)
        accept(listener, sup, model)

      {:error, reason} ->
        Logger.debug("Error A: #{reason}")
    end
  end

  def start_child(socket, shared) do
    {:ok,
     spawn_link(fn ->
       receive do
         :go ->
           loop(socket, shared)
       end
     end)}
  end

  defp loop(socket, shared) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        {cmd, transid} = Tcp.parse_req(data)
        Logger.info(inspect({cmd, transid}))

        case Shared.apply(shared, cmd) do
          {:ok, values} ->
            Logger.info("msg send")
            resp = Tcp.pack_res(cmd, values, transid)
            :ok = :gen_tcp.send(socket, resp)

          :error ->
            Logger.info("an error has occur")
        end

        loop(socket, shared)

      {:error, reason} ->
        # agregar shared
        Logger.info("Error R: #{reason}")
        # model = Shared.state(shared)
        # port = state(self())[:port]
        # Logger.info("Me reconectare")
        # start_link([model: model, port: port])
        # loop(socket, shared)
    end
  end
end
