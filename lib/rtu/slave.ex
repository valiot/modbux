defmodule Modbux.Rtu.Slave do
  @moduledoc """
  API for a Modbus RTU Slave device.
  """
  use GenServer, restart: :transient

  alias Modbux.Model.Shared
  alias Modbux.Rtu.{Slave, Framer}
  alias Modbux.Rtu
  alias Circuits.UART
  require Logger

  @timeout 1000
  @speed 115_200

  defstruct model_pid: nil,
            uart_pid: nil,
            tty: nil,
            uart_otps: nil,
            parent_pid: nil

  @doc """
  Starts a Modbus RTU Slave process.

  The following options are available:

    * `tty` - defines the serial port to spawn the Slave.
    * `gen_opts` - defines extra options for the Genserver OTP configuration.
    * `uart_opts` - defines extra options for the UART configuration (defaults:
          [speed: 115200, rx_framing_timeout: 1000]).
    * `model` - defines the DB initial state.
    * `active` - (`true` or `false`) enable/disable DB updates notifications (mailbox).

  The messages (when active mode is true) have the following form:

    `{:modbus_rtu, {:slave_request, payload}}`

  or

    `{:modbus_rtu, {:slave_error, payload, reason}}`

  The following are some reasons:

    * `:ecrc`  - corrupted message (invalid crc).
    * `:einval`  - invalid function.
    * `:eaddr`  - invalid memory address requested.

  ## Model (DB)

  The model or data base (DB) defines the slave memory map, the DB is defined by the following syntax:
  ```elixir
  %{slave_id => %{{memory_type, address_number} => value}}
  ```
  where:
    * `slave_id` - specifies a unique unit address from 1 to 247.
    * `memory_type` - specifies the memory between:
         * `:c` - Discrete Output Coils.
         * `:i` - Discrete Input Contacts.
         * `:ir` - Analog Input Registers.
         * `:hr` - Analog Output Registers.
    * `address_number` - specifies the memory address.
    * `value` - the current value from that memory.

  ## Example

  ```elixir
  model = %{80 => %{{:c, 20818} => 0, {:hr, 20818} => 0}}
  Modbux.Tcp.Server.start_link(model: model, port: 2000)
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
  Gets the Slave state.
  """
  @spec state(atom | pid | {atom, any} | {:via, atom, any}) :: any
  def state(pid) do
    GenServer.call(pid, :state)
  end

  @doc """
  Updates the state of the Slave DB.

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
  @spec request(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def request(pid, cmd) do
    GenServer.call(pid, {:request, cmd})
  end

  @doc """
  Gets the current state of the Slave DB.
  """
  @spec get_db(atom | pid | {atom, any} | {:via, atom, any}) :: any
  def get_db(pid) do
    GenServer.call(pid, :get_db)
  end

  @doc """
  Send a raw frame through the serial port.
  """
  @spec raw_write(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def raw_write(pid, data) do
    GenServer.call(pid, {:raw_write, data})
  end

  def init({params, parent_pid}) do
    parent_pid = if Keyword.get(params, :active, false), do: parent_pid
    tty = Keyword.fetch!(params, :tty)
    model = Keyword.fetch!(params, :model)
    Logger.debug("(#{__MODULE__}) Starting Modbux Slave at \"#{tty}\"")
    uart_otps = Keyword.get(params, :uart_otps, speed: @speed, rx_framing_timeout: @timeout)
    {:ok, model_pid} = Shared.start_link(model: model)
    {:ok, u_pid} = UART.start_link()
    UART.open(u_pid, tty, [framing: {Framer, behavior: :slave}] ++ uart_otps)

    state = %Slave{
      model_pid: model_pid,
      parent_pid: parent_pid,
      tty: tty,
      uart_pid: u_pid,
      uart_otps: uart_otps
    }

    {:ok, state}
  end

  def terminate(:normal, _state), do: nil

  def terminate(reason, state) do
    Logger.error("(#{__MODULE__}) Error: #{inspect(reason)}, state: #{inspect(state)}")
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call({:request, cmd}, _from, state) do
    res =
      case Shared.apply(state.model_pid, cmd) do
        {:ok, values} ->
          Logger.debug("(#{__MODULE__}) DB request: #{inspect(cmd)}, #{inspect(values)}")
          values

        nil ->
          Logger.debug("(#{__MODULE__}) DB update: #{inspect(cmd)}")

        error ->
          Logger.debug("(#{__MODULE__}) An error has occur #{inspect(error)}")
          error
      end

    {:reply, res, state}
  end

  def handle_call(:get_db, _from, state) do
    {:reply, Shared.state(state.model_pid), state}
  end

  def handle_call({:raw_write, data}, _from, state) do
    UART.write(state.uart_pid, data)
    {:reply, :ok, state}
  end

  def handle_info({:circuits_uart, device, {:error, reason, bad_frame}}, state) do
    Logger.warn("(#{__MODULE__}) Error with \"#{device}\" received: #{bad_frame}, reason: #{reason}")

    case reason do
      :einval ->
        if valid_slave_id?(state, bad_frame) do
          response = Rtu.pack_res(bad_frame, :einval)
          Logger.debug("(#{__MODULE__}) Sending error code: #{inspect(response)}, reason: #{reason}")
          UART.write(state.uart_pid, response)
        end

      _ ->
        nil
    end

    if !is_nil(state.parent_pid), do: notify(state.parent_pid, reason, bad_frame)
    {:noreply, state}
  end

  def handle_info({:circuits_uart, _device, {:partial, data}}, state) do
    Logger.warn("(#{__MODULE__})  Timeout: #{inspect(data)}")
    {:noreply, state}
  end

  def handle_info({:circuits_uart, device, modbus_frame}, state) do
    Logger.debug("(#{__MODULE__}) Recieved from UART (#{device}): #{inspect(modbus_frame)}")
    cmd = Rtu.parse_req(modbus_frame)
    Logger.debug("(#{__MODULE__}) Received Modbux request: #{inspect(cmd)}")

    case Shared.apply(state.model_pid, cmd) do
      {:ok, values} ->
        response = Rtu.pack_res(cmd, values)
        if !is_nil(state.parent_pid), do: notify(state.parent_pid, nil, cmd)
        UART.write(state.uart_pid, response)

      {:error, reason} ->
        response = Rtu.pack_res(modbus_frame, reason)
        if !is_nil(state.parent_pid), do: notify(state.parent_pid, reason, cmd)
        UART.write(state.uart_pid, response)

        Logger.debug(
          "(#{__MODULE__}) An error has occur for cmd: #{inspect(cmd)}, response #{inspect(response)}"
        )

      nil ->
        nil
    end

    {:noreply, state}
  end

  # Catch all clause
  def handle_info(msg, state) do
    Logger.warn("(#{__MODULE__})  Unknown msg: #{inspect(msg)}")
    {:noreply, state}
  end

  defp valid_slave_id?(state, <<slave_id, _b_tail::binary>>) do
    state.model_pid
    |> Shared.state()
    |> Map.has_key?(slave_id)
  end

  defp notify(pid, nil, cmd) do
    send(pid, {:modbus_rtu, {:slave_request, cmd}})
  end

  defp notify(pid, reason, cmd) do
    send(pid, {:modbus_rtu, {:slave_error, cmd, reason}})
  end
end
