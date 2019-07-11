defmodule Modbus.Rtu.Slave do
  @moduledoc false
  alias Modbus.Model.Shared
  alias Modbus.Rtu.{Slave, Framer}
  alias Modbus.Rtu
  alias Circuits.UART
  require Logger

  defstruct model_pid: nil,
            uart_pid: nil,
            tty: nil,
            uart_otps: nil,
            parent_pid: nil

  def start_link(params) do
    gen_opts = Keyword.get(params, :gen_opts, [])
    GenServer.start_link(__MODULE__, {params, self()}, gen_opts)
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
    parent_pid = if Keyword.get(params, :active, false), do: parent_pid
    tty = Keyword.fetch!(params, :tty)
    model = Keyword.fetch!(params, :model)
    Logger.debug("(#{__MODULE__}) Starting Modbus Slave at \"#{tty}\"")
    uart_otps = Keyword.get(params, :uart_otps, speed: 115_200)
    {:ok, model_pid} = Shared.start_link(model: model)
    {:ok, u_pid} = UART.start_link()
    # checar specs de modbus para el rx_framing_timeout.
    UART.open(u_pid, tty, [framing: {Framer, behavior: :slave}, rx_framing_timeout: 500] ++ uart_otps)

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

  def handle_info({:circuits_uart, device, {:error, reason}}, state) do
    Logger.warn("(#{__MODULE__})  Error with \"#{device}\": #{reason}")
    # Notificar error
    {:noreply, state}
  end

  def handle_info({:circuits_uart, _device, {:partial, data}}, state) do
    Logger.warn("(#{__MODULE__})  Timeout: #{inspect(data)}")
    {:noreply, state}
  end

  def handle_info({:circuits_uart, device, modbus_frame}, state) do
    Logger.debug("(#{__MODULE__}) Recieved from UART (#{device}): #{inspect(modbus_frame)}")
    cmd = Rtu.parse_req(modbus_frame)
    Logger.debug("(#{__MODULE__}) Received Modbus request: #{inspect(cmd)}")

    case Shared.apply(state.model_pid, cmd) do
      {:ok, values} ->
        response = Rtu.pack_res(cmd, values)
        if !is_nil(state.parent_pid), do: notify(state.parent_pid, cmd)
        UART.write(state.uart_pid, response)

      {:error, reason} ->
        Logger.debug("(#{__MODULE__}) An error has occur for cmd: #{inspect(cmd)}")
        response = Rtu.pack_res(modbus_frame, reason)
        UART.write(state.uart_pid, response)

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

  defp notify(pid, cmd) do
    send(pid, {:modbus_rtu, {:slave_request, cmd}})
  end
end
