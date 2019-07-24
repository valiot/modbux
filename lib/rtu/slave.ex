defmodule Modbus.Rtu.Slave do
  @moduledoc """
  RTU Slave device.
  """
  use GenServer, restart: :transient

  alias Modbus.Model.Shared
  alias Modbus.Rtu.{Slave, Framer}
  alias Modbus.Rtu
  alias Circuits.UART
  require Logger

  @timeout 1000
  @speed 115_200

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

  def state(pid) do
    GenServer.call(pid, :state)
  end

  def request(pid, cmd) do
    GenServer.call(pid, {:request, cmd})
  end

  def get_db(pid) do
    GenServer.call(pid, :get_db)
  end

  def raw_write(pid, data) do
    GenServer.call(pid, {:raw_write, data})
  end

  def init({params, parent_pid}) do
    parent_pid = if Keyword.get(params, :active, false), do: parent_pid
    tty = Keyword.fetch!(params, :tty)
    model = Keyword.fetch!(params, :model)
    Logger.debug("(#{__MODULE__}) Starting Modbus Slave at \"#{tty}\"")
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
          Logger.debug("(#{__MODULE__}) An error has occur #{inspect error}")
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
    Logger.debug("(#{__MODULE__}) Received Modbus request: #{inspect(cmd)}")

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
