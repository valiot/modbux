defmodule Modbus.Tcp.Client do
  alias Modbus.Tcp.Client
  @timeout 2000
  @port 502
  @ip {0,0,0,0}
  @active false

  @moduledoc """
  TCP Master Client.

  ## Example

  ```elixir
  #run with: mix opto22
  alias Modbus.Tcp.Master

  # opto22 rack configured as follows
  # m0 - 4p digital input
  #  p0 - 24V
  #  p1 - 0V
  #  p2 - m1.p2
  #  p3 - m1.p3
  # m1 - 4p digital output
  #  p0 - NC
  #  p1 - NC
  #  p2 - m0.p2
  #  p3 - m0.p3
  # m2 - 2p analog input (-10V to +10V)
  #  p0 - m3.p0
  #  p1 - m3.p1
  # m3 - 2p analog output (-10V to +10V)
  #  p0 - m2.p0
  #  p1 - m2.p1

  {:ok, pid} = Master.start_link([ip: {10,77,0,2}, port: 502])

  #turn off m1.p0
  :ok = Master.exec(pid, {:fc, 1, 4, 0})
  #turn on m1.p1
  :ok = Master.exec(pid, {:fc, 1, 5, 1})
  #alternate m1.p2 and m1.p3
  :ok = Master.exec(pid, {:fc, 1, 6, [1, 0]})

  #https://www.h-schmidt.net/FloatConverter/IEEE754.html
  #write -5V (IEEE 754 float) to m3.p0
  #<<-5::float-32>> -> <<192, 160, 0, 0>>
  :ok = Master.exec(pid, {:phr, 1, 24, [0xc0a0, 0x0000]})
  :ok = Master.exec(pid, {:phr, 1, 24, Modbus.IEEE754.to_2_regs(-5.0, :be)})
  #write +5V (IEEE 754 float) to m3.p1
  #<<+5::float-32>> -> <<64, 160, 0, 0>>
  :ok = Master.exec(pid, {:phr, 1, 26, [0x40a0, 0x0000]})
  :ok = Master.exec(pid, {:phr, 1, 26, Modbus.IEEE754.to_2_regs(+5.0, :be)})

  :timer.sleep(20) #outputs settle delay

  #read previous coils as inputs
  {:ok, [0, 1, 1, 0]} = Master.exec(pid, {:ri, 1, 4, 4})

  #read previous analog channels as input registers
  {:ok, [0xc0a0, 0x0000, 0x40a0, 0x0000]} = Master.exec(pid, {:rir, 1, 24, 4})
  {:ok, data} = Master.exec(pid, {:rir, 1, 24, 4})
  [-5.0, +5.0] = Modbus.IEEE754.from_2n_regs(data, :be)
  ```
  """
  alias Modbus.Tcp
  require Logger
  @to 2000

  defstruct ip: nil,
            tcp_port: nil,
            socket: nil,
            timeout: @to,
            active: false,
            transid: 0,
            status: nil


  @type client_option ::
        {:ip, {byte(),byte(),byte(),byte()}}
      | {:active, boolean}
      | {:tcp_port, non_neg_integer}
      | {:timeout, non_neg_integer}
  ##########################################
  # Public API
  ##########################################

  @doc """
  Starts the Client.

  `state` is a keyword list where:
  `ip` is the internet address to connect to.
  `tcp_port` is the tcp port number to connect to.
  `socket` is the port of the Modbus Client.
  `timeout` is the connection timeout.
  `active` the way in which massages are received.
  'transid' the actual transaction id.
  'status' the Client status.


  Returns `{:ok, pid}`.

  ## Example

  ```elixir
  Modbus.Tcp.Master.start_link([ip: {10,77,0,2}, port: 502, timeout: 2000])
  ```
  """
  @spec start_link([client_option], [term]) :: {:ok, pid} | {:error, term}
  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end


  @doc """
  Stops the Client.
  """
  @spec stop(GenServer.server()) :: :ok | :error
  def stop(pid) do
    if Process.info(pid) do
      Agent.stop(pid)
    else
      :error
    end
  end

  @doc """
  Gets the state of the Client.
  """
  #@spec state(GenServer.server()) :: {term() | :closed, [uart_option]}
  def state(pid) do
    Agent.get(pid, fn state -> state end)
  end

   @doc """
  Configure the Modbus client (`status` mmust be `:closed`).
  """
  @spec configure(GenServer.server(), [client_option]) :: :ok | {:error, term}
  def configure(pid, params) do
    Agent.get_and_update(pid,fn state -> update_state(state, params) end) #{respuesta(cmd), estado}
  end

  @doc """
  Executes a Modbus TCP command.

  `cmd` is one of:

  - `{:rc, slave, address, count}` read `count` coils.
  - `{:ri, slave, address, count}` read `count` inputs.
  - `{:rhr, slave, address, count}` read `count` holding registers.
  - `{:rir, slave, address, count}` read `count` input registers.
  - `{:fc, slave, address, value}` force single coil.
  - `{:phr, slave, address, value}` preset single holding register.
  - `{:fc, slave, address, values}` force multiple coils.
  - `{:phr, slave, address, values}` preset multiple holding registers.

  Returns `:ok` | `{:ok, [values]}`.
  """
  def exec(pid, cmd, timeout \\ @to) do
    Logger.info(inspect(state(pid)))
    case state(pid) do
      {:error, reason} ->
        {:error, reason}
      _->
        Agent.get_and_update(pid, fn {socket, transid} ->
        request = Tcp.pack_req(cmd, transid)
        length = Tcp.res_len(cmd)
        :gen_tcp.send(socket, request)
        case :gen_tcp.recv(socket, length, timeout) do
          {:ok, response} ->
            values = Tcp.parse_res(cmd, response, transid)
            Logger.info(inspect(values))
            case values do
              nil -> {:ok, {socket, transid + 1}}
              _ -> {{:ok, values}, {socket, transid + 1}}
            end
          {:error, reason} ->
            Logger.debug("Error: #{reason}")
            {{:error, reason}, {socket, transid}}
        end
        end)
    end
  end


  @doc """
  Send a request to a connected Modbus server.
  """
  def request(pid, cmd) do
    Agent.get_and_update(pid,fn state -> send_request(state, cmd) end)
  end

   @doc """
  read the confirmation of the connected Modbus server.
  """
  def confirmation(pid, cmd) do
    Agent.get_and_update(pid,fn state -> read_confirmation(state, cmd) end)
  end

  @doc """
  Connect the Modbus client to a server.
  """
  def connect(pid) do
    Agent.get_and_update(pid,fn state -> connect_socket(state) end) #{respuesta(cmd), estado}
  end

  @doc """
  Close the tcp port of the Modbus client.
  """
  def close(pid) do
    Agent.get_and_update(pid,fn state -> close_tcp_port(state) end) #{respuesta(cmd), estado}
  end


  #returns the state ()
  defp init(args) do
    port = args[:port] || @port
    ip = args[:ip] || @ip
    timeout = args[:timeout] || @timeout
    status = :closed
    active =
      if args[:active] == nil do
        @active
      else
        args[:active]
      end
    state = %Client{ip: ip, tcp_port: port, timeout: timeout, status: status, active: active}
    state
  end

  defp connect_socket(state) do
    Logger.debug(inspect(state))
    case :gen_tcp.connect(state.ip, state.tcp_port, [:binary, packet: :raw, active: state.active], state.timeout) do
      {:ok, socket} ->
        new_state = %Client{state | socket: socket, status: :connected} #state
        {:ok, new_state}
      {:error, reason} ->
        Logger.debug(reason)
        {{:error,reason}, state} #state
    end
  end

  defp send_request(state, cmd) do

  end

  defp read_confirmation(state, cmd) do

  end

  defp close_tcp_port(state) do
    Logger.debug(inspect(state))
    if state.socket != nil do
      case :gen_tcp.close(state.socket) do
            :ok ->
              new_state = %Client{state | socket: nil, status: :closed} #state
              {:ok, new_state}
            {:error, reason} ->
              Logger.debug(reason)
              {{:error,reason}, state} #state
      end
    else
      Logger.info("No port to close")
      {{:error, :closed}, state} #state
    end
  end

  defp update_state(state, args) do
    case state.status do
      :closed ->
        port = args[:port] || state.tcp_port
        ip = args[:ip] || state.ip
        timeout = args[:timeout] || state.timeout
        active =
          if args[:active] == nil do
            state.active
          else
            args[:active]
          end

        new_state = %Client{state | ip: ip, tcp_port: port, timeout: timeout, active: active}
        {:ok, new_state}
      _ ->
        {:error, state}
    end

  end
end
