defmodule Modbux.Tcp.Client do
  @moduledoc """
  API for Modbus TCP Client.
  """
  alias Modbux.Tcp.Client
  alias Modbux.Tcp
  use GenServer, restart: :permanent, shutdown: 500
  require Logger

  @timeout 2000
  @tcp_port 502
  @ip {0, 0, 0, 0}
  @active false
  @packet_format :raw

  defstruct ip: nil,
            tcp_port: nil,
            socket: nil,
            timeout: @timeout,
            active: false,
            packet_format: @packet_format,
            transaction_id: 0,
            status: nil,
            d_pid: nil,
            msg_len: 0,
            pending_msg: %{},
            cmd: nil

  @type client_option ::
          {:ip, {byte(), byte(), byte(), byte()}}
          | {:active, boolean}
          | {:tcp_port, non_neg_integer}
          | {:timeout, non_neg_integer}

  @doc """
  Starts a Modbus TCP Client process.

  The following options are available:

    * `ip` - is the internet address of the desired Modbux TCP Server.
    * `tcp_port` - is the desired Modbux TCP Server tcp port number.
    * `timeout` - is the connection timeout.
    * `packet_fotmat` - is the :gen_tcp `packet` argument, it accepts 0 | 1 | 2 | 4 | :raw, values (default: :raw).
    * `active` - (`true` or `false`) specifies whether data is received as
        messages (mailbox) or by calling `confirmation/1` each time `request/2` is called.

    The messages (when active mode is true) have the following form:

    `{:modbus_tcp, cmd, values}`

  ## Example

  ```elixir
  Modbux.Tcp.Client.start_link(ip: {10,77,0,2}, port: 502, timeout: 2000, active: true)
  ```
  """
  def start_link(params, opts \\ []) do
    GenServer.start_link(__MODULE__, params, opts)
  end

  @doc """
  Stops the Client.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Gets the state of the Client.
  """
  def state(pid) do
    GenServer.call(pid, :state)
  end

  @doc """
  Configure the Client (`status` must be `:closed`).

  The following options are available:

  * `ip` - is the internet address of the desired Modbux TCP Server.
  * `tcp_port` - is the Modbux TCP Server tcp port number .
  * `timeout` - is the connection timeout.
  * `packet_fotmat` - is the :gen_tcp `packet` argument, it accepts 0 | 1 | 2 | 4 | :raw, values (default: :raw).
  * `active` - (`true` or `false`) specifies whether data is received as
       messages (mailbox) or by calling `confirmation/1` each time `request/2` is called.
  """
  def configure(pid, params) do
    GenServer.call(pid, {:configure, params})
  end

  @doc """
  Connect the Client to a Server.
  """
  def connect(pid) do
    GenServer.call(pid, :connect)
  end

  @doc """
  Close the tcp port of the Client.
  """
  def close(pid) do
    GenServer.call(pid, :close)
  end

  @doc """
  Send a request to Modbux TCP Server.

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
  def request(pid, cmd) do
    GenServer.call(pid, {:request, cmd})
  end

  @doc """
  In passive mode (active: false), reads the confirmation of the connected Modbux Server.
  """
  def confirmation(pid) do
    GenServer.call(pid, :confirmation)
  end

  @doc """
  In passive mode (active: false), flushed the pending messages.
  """
  def flush(pid) do
    GenServer.call(pid, :flush)
  end

  # callbacks
  def init(args) do
    with tcp_port <- Keyword.get(args, :tcp_port, @tcp_port),
         true <- is_integer(tcp_port),
         ip <- Keyword.get(args, :ip, @ip),
         true <- is_tuple(ip),
         timeout <- Keyword.get(args, :timeout, @timeout),
         true <- is_integer(timeout),
         packet_format <- Keyword.get(args, :packet_format, @packet_format),
         true <- packet_format in [0, 1, 2, 4, :raw, :line],
         active <- Keyword.get(args, :active, @active),
         true <- is_boolean(active) do
      state = %Client{
        ip: ip,
        tcp_port: tcp_port,
        timeout: timeout,
        active: active,
        packet_format: packet_format,
        status: :closed
      }

      {:ok, state}
    else
      _ ->
        {:stop, :einval}
    end
  end

  def handle_call(:state, from, state) do
    Logger.debug("(#{__MODULE__}, :state) from: #{inspect(from)}")
    {:reply, state, state}
  end

  def handle_call({:configure, args}, _from, %{status: :closed} = state) do
    with tcp_port <- Keyword.get(args, :tcp_port, state.tcp_port),
         true <- is_integer(tcp_port),
         ip <- Keyword.get(args, :ip, state.ip),
         true <- is_tuple(ip),
         timeout <- Keyword.get(args, :timeout, state.timeout),
         true <- is_integer(timeout),
         d_pid <- Keyword.get(args, :d_pid, state.d_pid),
         true <- is_pid(d_pid) or is_nil(d_pid),
         packet_format <- Keyword.get(args, :packet_format, state.packet_format),
         true <- packet_format in [0, 1, 2, 4, :raw, :line],
         active <- Keyword.get(args, :active, state.active),
         true <- is_boolean(active) do
      new_state = %Client{
        state
        | ip: ip,
          tcp_port: tcp_port,
          timeout: timeout,
          active: active,
          packet_format: packet_format,
          d_pid: d_pid
      }

      {:reply, :ok, new_state}
    else
      _ ->
        {:reply, {:error, :einval}, state}
    end
  end

  def handle_call({:configure, _args}, _from, state) do
    {:reply, :error, state}
  end

  def handle_call(:connect, {from, _ref}, %{d_pid: d_pid} = state) do
    Logger.debug("(#{__MODULE__}, :connect) state: #{inspect(state)} from: #{inspect(from)}")

    case :gen_tcp.connect(
           state.ip,
           state.tcp_port,
           [:binary, packet: state.packet_format, active: state.active],
           state.timeout
         ) do
      {:ok, socket} ->
        ctrl_pid = d_pid || from
        new_state = %Client{state | socket: socket, status: :connected, d_pid: ctrl_pid}
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("(#{__MODULE__}, :connect) reason #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:close, _from, %{socket: nil} = state) do
    Logger.error("(#{__MODULE__}, :close) No port to close")
    {:reply, {:error, :closed}, state}
  end

  def handle_call(:close, _from, state) do
    Logger.debug("(#{__MODULE__}, :close) state: #{inspect(state)}")
    {:reply, :ok, close_socket(state)}
  end

  def handle_call({:request, _cmd}, _from, %{status: :closed} = state) do
    Logger.debug("(#{__MODULE__}, :request) state: #{inspect(state)}")
    {:reply, {:error, :closed}, state}
  end

  def handle_call({:request, cmd}, _from, %{status: :connected} = state) do
    Logger.debug("(#{__MODULE__}, :request) state: #{inspect(state)}")
    {genserver_response, new_state} = send_modbus_tcp_request(cmd, state)
    {:reply, genserver_response, new_state}
  end

  # only in passive mode (active: false)
  def handle_call(:confirmation, _from, %{status: status, active: active} = state)
      when status == :closed or active == true do
    Logger.debug("(#{__MODULE__}, :confirmation) state: #{inspect(state)}")
    {:reply, {:error, :closed}, state}
  end

  def handle_call(:confirmation, _from, %{status: :connected} = state) do
    Logger.debug("(#{__MODULE__}, :confirmation) state: #{inspect(state)}")
    {genserver_response, new_state} = receive_modbus_tcp_confirmation(state)
    {:reply, genserver_response, new_state}
  end

  def handle_call(:flush, _from, state) do
    new_state = %Client{state | pending_msg: %{}}
    {:reply, {:ok, state.pending_msg}, new_state}
  end

  # only for active mode (active: true)
  def handle_info({:tcp, _port, response}, state) do
    Logger.debug("(#{__MODULE__}, :message_active) response: #{inspect(response)} state: #{inspect(state)}")

    h = :binary.at(response, 0)
    l = :binary.at(response, 1)
    transaction_id = h * 256 + l
    Logger.debug("(#{__MODULE__}, :message_active) transaction_id: #{inspect(transaction_id)}")

    case Map.fetch(state.pending_msg, transaction_id) do
      :error ->
        Logger.error("(#{__MODULE__}, :message_active) unknown transaction id")
        {:noreply, state}

      {:ok, cmd} ->
        values = Tcp.parse_res(cmd, response, transaction_id)
        msg = {:modbus_tcp, cmd, values}
        send(state.d_pid, msg)
        new_pending_msg = Map.delete(state.pending_msg, transaction_id)
        new_state = %Client{state | cmd: nil, msg_len: 0, pending_msg: new_pending_msg}
        {:noreply, new_state}
    end
  end

  def handle_info({:tcp_closed, _port}, state) do
    Logger.info("(#{__MODULE__}, :tcp_close) Server close the port")
    new_state = close_socket(state)
    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    Logger.error("(#{__MODULE__}, :random_msg) msg: #{inspect(msg)}")
    {:noreply, state}
  end

  defp close_socket(state) do
    :ok = :gen_tcp.close(state.socket)
    %Client{state | socket: nil, status: :closed}
  end

  defp send_modbus_tcp_request(cmd, state) do
    request = Tcp.pack_req(cmd, state.transaction_id)
    length = Tcp.res_len(cmd)

    case :gen_tcp.send(state.socket, request) do
      :ok ->
        new_state = build_successful_request_new_state(cmd, length, state)

        {:ok, new_state}

      {:error, :closed} ->
        new_state = close_socket(state)
        {{:error, :closed}, new_state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp build_successful_request_new_state(cmd, length, %{active: false} = state),
    do: %Client{state | msg_len: length, cmd: cmd}

  defp build_successful_request_new_state(cmd, length, %{active: true} = state) do
    pending_msg = Map.put(state.pending_msg, state.transaction_id, cmd)
    transaction_id = increase_transaction_id(state.transaction_id)

    %Client{
      state
      | msg_len: length,
        cmd: cmd,
        pending_msg: pending_msg,
        transaction_id: transaction_id
    }
  end

  defp increase_transaction_id(0xFFFF), do: 0
  defp increase_transaction_id(transaction_id), do: transaction_id + 1

  defp receive_modbus_tcp_confirmation(state) do
    case :gen_tcp.recv(state.socket, state.msg_len, state.timeout) do
      {:ok, response} ->
        Logger.debug("(#{__MODULE__}, :confirmation) response: #{inspect(response)}")

        values = Tcp.parse_res(state.cmd, response, state.transaction_id)

        transaction_id = increase_transaction_id(state.transaction_id)

        new_state = %Client{state | transaction_id: transaction_id, cmd: nil, msg_len: 0}

        build_successful_confirmation_new_state(values, new_state)

      {:error, reason} ->
        Logger.error("(#{__MODULE__}, :confirmation) reason: #{inspect(reason)}")
        new_state = close_socket(state)
        new_state = %Client{new_state | cmd: nil, msg_len: 0}
        {{:error, reason}, new_state}
    end
  end

  # Write Request
  defp build_successful_confirmation_new_state(nil, new_state), do: {:ok, new_state}
  # Read Request
  defp build_successful_confirmation_new_state(values, new_state), do: {{:ok, values}, new_state}
end
