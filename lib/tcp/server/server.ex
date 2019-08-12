defmodule Modbux.Tcp.Server do
  @moduledoc """
  API for Modbus TCP Server.
  """
  alias Modbux.Tcp.Server
  alias Modbux.Model.Shared
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

  @doc """
  Starts a Modbus TCP Server process.

  The following options are available:

    * `port` - is the Modbux TCP Server tcp port number.
    * `timeout` - is the connection timeout.
    * `model` - defines the DB initial state.
    * `sup_otps` - server supervisor OTP options.
    * `active` - (`true` or `false`) enable/disable DB updates notifications (mailbox).

  The messages (when active mode is true) have the following form:

    `{:modbus_tcp, {:slave_request, payload}}`

  ## Model (DB)

  The model or data base (DB) defines the server memory map, the DB is defined by the following syntax:
  ```elixir
  %{slave_id => %{{memory_type, address_number} => value}}
  ```
  where:
    * `slave_id` - specify a unique unit address from 1 to 247.
    * `memory_type` - specify the memory between:
         * `:c` - Discrete Output Coils.
         * `:i` - Discrete Input Contacts.
         * `:ir` - Analog Input Registers.
         * `:hr` - Analog Output Registers.
    * `address_number` - specify the memory address.
    * `value` - the current value from that memory.

  ## Example

  ```elixir
  model = %{80 => %{{:c, 20818} => 0, {:hr, 20818} => 0}}
  Modbux.Tcp.Server.start_link(model: model, port: 2000)
  ```
  """
  @spec start_link(any, [
          {:debug, [:log | :statistics | :trace | {any, any}]}
          | {:hibernate_after, :infinity | non_neg_integer}
          | {:name, atom | {:global, any} | {:via, atom, any}}
          | {:spawn_opt,
             :link
             | :monitor
             | {:fullsweep_after, non_neg_integer}
             | {:min_bin_vheap_size, non_neg_integer}
             | {:min_heap_size, non_neg_integer}
             | {:priority, :high | :low | :normal}}
          | {:timeout, :infinity | non_neg_integer}
        ]) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(params, opts \\ []) do
    GenServer.start_link(__MODULE__, {params, self()}, opts)
  end

  @spec stop(atom | pid | {atom, any} | {:via, atom, any}) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Updates the state of the Server DB.

  `cmd` is a 4 elements tuple, as follows:
    - `{:rc, slave, address, count}` read `count` coils.
    - `{:ri, slave, address, count}` read `count` inputs.
    - `{:rhr, slave, address, count}` read `count` holding registers.
    - `{:rir, slave, address, count}` read `count` input registers.
    - `{:fc, slave, address, value}` force single coil.
    - `{:phr, slave, address, value}` preset single holding register.
    - `{:fc, slave, address, values}` force multiple coils.
    - `{:phr, slave, address, values}` preset multiple holding registers.
  """
  @spec update(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def update(pid, cmd) do
    GenServer.call(pid, {:update, cmd})
  end

  @doc """
  Gets the current state of the Server DB.
  """
  @spec get_db(atom | pid | {atom, any} | {:via, atom, any}) :: any
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
          Logger.debug("(#{__MODULE__}) DB request: #{inspect(request)}, #{inspect(values)}")
          values

        nil ->
          Logger.debug("(#{__MODULE__}) DB update: #{inspect(request)}")

        error ->
          Logger.debug("(#{__MODULE__}) An error has occur")
          error
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
