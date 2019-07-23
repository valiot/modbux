defmodule Modbus.Tcp.Server do
  @moduledoc """
  TCP Server.
  """
  alias Modbus.Tcp.Server
  alias Modbus.Model.Shared
  use GenServer, restart: :transient
  require Logger

  @port 502
  @to :infinity

  defstruct ip: nil,
            model_pid: nil,
            tcp_port: nil,
            timeout: nil,
            listener: nil,
            parent_pid: nil,
            sup_pid: nil,
            acceptor_pid: nil

  def start_link(params, opts \\ []) do
    GenServer.start_link(__MODULE__, {params, self()}, opts)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def update(pid, cmd) do
    GenServer.call(pid, {:update, cmd})
  end

  def get_db(pid) do
    GenServer.call(pid, :get_db)
  end

  def init({params, parent_pid}) do
    port = Keyword.get(params, :port, @port)
    timeout = Keyword.get(params, :timeout, @to)
    parent_pid = if Keyword.get(params, :active, false), do: parent_pid
    model = Keyword.fetch!(params, :model)
    {:ok, model_pid} = Shared.start_link(model: model)
    sup_opts = Keyword.get(params, :sup_opts, [])
    {:ok, sup_pid} = Server.Supervisor.start_link(sup_opts)

    state = %Server{
      tcp_port: port,
      model_pid: model_pid,
      timeout: timeout,
      parent_pid: parent_pid,
      sup_pid: sup_pid
    }

    {:ok, state, {:continue, :setup}}
  end

  def terminate(:normal, _state), do: nil

  def terminate(reason, state) do
    Logger.error("(#{__MODULE__}) Error: #{inspect(reason)}")
    :gen_tcp.close(state.listener)
  end

  def handle_call({:update, request}, _from, state) do
    res =
      case Shared.apply(state.model_pid, request) do
        {:ok, values} ->
          Logger.debug("(#{__MODULE__}) DB update: #{inspect(request)}, #{inspect(values)}")
          :ok

        :error ->
          Logger.debug("(#{__MODULE__}) an error has occur")
          :error
      end

    {:reply, res, state}
  end

  def handle_call(:get_db, _from, state) do
    {:reply, Shared.state(state.model_pid), state}
  end

  def handle_continue(:setup, state) do
    new_state = listener_setup(state)
    {:noreply, new_state}
  end

  defp listener_setup(state) do
    case :gen_tcp.listen(state.tcp_port, [:binary, packet: :raw, active: true, reuseaddr: true]) do
      {:ok, listener} ->
        {:ok, {ip, _port}} = :inet.sockname(listener)
        accept = Task.async(fn -> accept(state, listener) end)
        %Server{state | ip: ip, acceptor_pid: accept, listener: listener}

      {:error, :eaddrinuse} ->
        Logger.error("(#{__MODULE__}) Error: A listener is still alive")
        close_alive_sockets(state.tcp_port)
        Process.sleep(100)
        listener_setup(state)

      {:error, reason} ->
        Logger.error("(#{__MODULE__}) Error in Listen: #{reason}")
        Process.sleep(1000)
        listener_setup(state)
    end
  end

  def close_alive_sockets(port) do
    Port.list()
    |> Enum.filter(fn x -> Port.info(x)[:name] == 'tcp_inet' end)
    |> Enum.filter(fn x ->
      {:ok, {{0, 0, 0, 0}, port}} == :inet.sockname(x) || {:ok, {{127, 0, 0, 1}, port}} == :inet.sockname(x)
    end)
    |> Enum.each(fn x -> :gen_tcp.close(x) end)
  end

  defp accept(state, listener) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        {:ok, pid} =
          Server.Supervisor.start_child(state.sup_pid, Server.Handler, [
            socket,
            state.model_pid,
            state.parent_pid
          ])

        Logger.debug("(#{__MODULE__}) New Client socket: #{inspect(socket)}, pid: #{inspect(pid)}")

        case :gen_tcp.controlling_process(socket, pid) do
          :ok ->
            nil

          error ->
            Logger.error("(#{__MODULE__}) Error in controlling process: #{inspect(error)}")
        end

        accept(state, listener)

      {:error, reason} ->
        Logger.error("(#{__MODULE__}) Error Accept: #{inspect(reason)}")
        exit(reason)
    end
  end
end
