defmodule Modbux.Rtu.Master do
  @moduledoc """
  API for a Modbus RTU Master device.
  """
  use GenServer, restart: :transient

  alias Modbux.Rtu.{Master, Framer}
  alias Modbux.Rtu
  alias Circuits.UART
  require Logger

  @timeout 1000
  @speed 115_200

  defstruct tty: nil,
            timeout: nil,
            cmd: nil,
            active: false,
            uart_opts: nil,
            uart_pid: nil,
            parent_pid: nil

  @doc """
  Starts a Modbus RTU Master process.

  The following options are available:

    * `tty` - defines the serial port to spawn the Master.
    * `timeout` - defines slave timeout.
    * `active` - (`true` or `false`) specifies whether data is received as
        messages (mailbox) or by calling `request/2`.
    * `gen_opts` - defines extra options for the Genserver OTP configuration.
    * `uart_opts` - defines extra options for the UART configuration (defaults:
          [speed: 115200, rx_framing_timeout: 1000]).

  The messages (when active mode is true) have the following form:

    `{:modbus_rtu, {:slave_response, cmd, values}}`
  or

    `{:modbus_rtu, {:slave_error, payload, reason}}`

  The following are some reasons:

    * `:ecrc`  - corrupted message (invalid crc).
    * `:einval`  - invalid function.
    * `:eaddr`  - invalid memory address requested.

  ## Example

  ```elixir
  Modbux.Rtu.Master.start_link(tty: "tnt0", active: true, uart_opts: [speed: 9600])
  ```
  """
  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(params) do
    gen_opts = Keyword.get(params, :gen_opts, [])
    GenServer.start_link(__MODULE__, {params, self()}, gen_opts)
  end

  @spec stop(atom | pid | {atom, any} | {:via, atom, any}) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Gets the Master state.
  """
  def state(pid) do
    GenServer.call(pid, :state)
  end

  @doc """
  Configure the Master serial port.

  The following options are available:

    * `tty` - defines the serial port to spawn the Master.
    * `timeout` - defines slave timeout.
    * `active` - (`true` or `false`) specifies whether data is received as
        messages (mailbox) or by calling `request/2`.
    * `gen_opts` - defines extra options for the Genserver OTP configuration.
    * `uart_opts` - defines extra options for the UART configuration.

  """
  def configure(pid, params) do
    GenServer.call(pid, {:configure, {params, self()}})
  end

  @doc """
  Open the Master serial port.
  """
  def open(pid) do
    GenServer.call(pid, :open)
  end

  @doc """
  Close the Master serial port.
  """
  def close(pid) do
    GenServer.call(pid, :close)
  end

  @doc """
  Send a request to Modbus RTU Slave.

  `cmd` is one of:
    - `{:rc, slave, address, count}` read `count` coils.
    - `{:ri, slave, address, count}` read `count` inputs.
    - `{:rhr, slave, address, count}` read `count` holding registers.
    - `{:rir, slave, address, count}` read `count` input registers.
    - `{:fc, slave, address, value}` force single coil.
    - `{:phr, slave, address, value}` preset single holding register.
    - `{:fc, slave, address, values}` force multiple coils.
    - `{:phr, slave, address, values}` preset multiple holding registers.
  """
  @spec request(atom | pid | {atom, any} | {:via, atom, any}, tuple()) ::
          :ok | {:ok, list()} | {:error, String.t()}
  def request(pid, cmd) do
    GenServer.call(pid, {:request, cmd})
  end

  @doc """
  Read and parse the last request (if the last request timeouts).
  """
  @spec read(atom | pid | {atom, any} | {:via, atom, any}) :: any
  def read(pid) do
    GenServer.call(pid, :read)
  end

  def terminate(:normal, _state), do: nil

  def terminate(reason, state) do
    Logger.error("(#{__MODULE__}) Error: #{inspect(reason)}, state: #{inspect(state)}")
  end

  # Callbacks
  def init({params, parent_pid}) do
    active = Keyword.get(params, :active, false)
    parent_pid = if active, do: parent_pid
    timeout = Keyword.get(params, :timeout, @timeout)
    tty = Keyword.fetch!(params, :tty)
    Logger.debug("(#{__MODULE__}) Starting Modbux Master at \"#{tty}\"")
    uart_opts = Keyword.get(params, :uart_opts, speed: @speed, rx_framing_timeout: @timeout)
    {:ok, u_pid} = UART.start_link()
    UART.open(u_pid, tty, [framing: {Framer, behavior: :master}, active: false] ++ uart_opts)
    Logger.debug("(#{__MODULE__}) Reported UART configuration: \"#{inspect(UART.configuration(u_pid))}\"")

    state = %Master{
      parent_pid: parent_pid,
      tty: tty,
      active: active,
      uart_pid: u_pid,
      timeout: timeout,
      uart_opts: uart_opts
    }

    {:ok, state}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call(:read, _from, state) do
    res = unless is_nil(state.cmd), do: uart_read(state, state.cmd)
    {:reply, res, state}
  end

  def handle_call(:open, _from, %{uart_pid: u_pid, tty: tty, uart_opts: uart_opts} = state) do
    UART.open(u_pid, tty, [framing: {Framer, behavior: :master}, active: false] ++ uart_opts)
    {:reply, :ok, state}
  end

  def handle_call(:close, _from, state) do
    UART.close(state.uart_pid)
    {:reply, :ok, state}
  end

  def handle_call({:request, cmd}, _from, state) do
    uart_frame = Rtu.pack_req(cmd)
    Logger.debug("(#{__MODULE__}) Frame: #{inspect(uart_frame, base: :hex)}")
    UART.flush(state.uart_pid)
    UART.write(state.uart_pid, uart_frame)

    res =
      if state.active do
        Task.start_link(__MODULE__, :async_uart_read, [state, cmd])
        :ok
      else
        uart_read(state, cmd)
      end

    {:reply, res, %{state | cmd: cmd}}
  end

  def handle_call({:configure, {params, parent_pid}}, _from, state) do
    active = Keyword.get(params, :active, false)
    parent_pid = if active, do: parent_pid
    timeout = Keyword.get(params, :timeout, state.timeout)
    tty = Keyword.get(params, :tty, state.tty)
    uart_opts = Keyword.get(params, :uart_opts, state.uart_opts)
    Logger.debug("(#{__MODULE__}) Starting Modbux Master at \"#{tty}\"")

    UART.close(state.uart_pid)
    UART.stop(state.uart_pid)

    {:ok, u_pid} = UART.start_link()
    UART.open(u_pid, tty, [framing: {Framer, behavior: :master}, active: false] ++ uart_opts)

    new_state = %Master{
      parent_pid: parent_pid,
      tty: tty,
      active: active,
      uart_pid: u_pid,
      timeout: timeout,
      uart_opts: uart_opts
    }

    {:reply, :ok, new_state}
  end

  # Catch all clause
  def handle_info(msg, state) do
    Logger.warning("(#{__MODULE__}) Unknown msg: #{inspect(msg)}")
    {:noreply, state}
  end

  def async_uart_read(state, cmd) do
    uart_read(state, cmd) |> notify(state, cmd)
  end

  defp uart_read(state, cmd) do
    case UART.read(state.uart_pid, state.timeout) do
      {:ok, ""} ->
        Logger.warning("(#{__MODULE__}) Timeout")
        {:error, :timeout}

      {:ok, {:error, reason, msg}} ->
        Logger.warning("(#{__MODULE__}) Error in frame: #{inspect(msg)}, reason: #{inspect(reason)}")
        {:error, reason}

      {:ok, slave_response} ->
        Rtu.parse_res(cmd, slave_response) |> pack_res()

      {:error, reason} ->
        Logger.warning("(#{__MODULE__}) Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp notify({:error, reason}, state, cmd),
    do: send(state.parent_pid, {:modbus_rtu, {:slave_error, cmd, reason}})

  defp notify({:ok, slave_response}, state, cmd),
    do: send(state.parent_pid, {:modbus_rtu, {:slave_response, cmd, slave_response}})

  defp notify(:ok, state, cmd), do: send(state.parent_pid, {:modbus_rtu, {:slave_response, cmd, :ok}})

  defp pack_res(nil), do: :ok
  defp pack_res(value) when is_tuple(value), do: value
  defp pack_res(value), do: {:ok, value}
end
