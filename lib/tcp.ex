defmodule Modbus.TCP do
  @moduledoc """
  Server module to handle a socket connection.
  """
  use GenServer

  ##########################################
  # Public API
  ##########################################

  @doc """
  Starts the GenServer.

  `state` is  a keyword list to be merged with the following defaults:

  ```elixir
  %{
    ip: {0,0,0,0},
    port: 0,
    timeout: 400,
  }
  ```

  `ip` is the internet address to connect to.

  `port` is the tcp port number to connect to.

  Returns `{:ok, pid}`.

  ## Example

  ```elixir
  Modbus.TCP.start_link([ip: {10,77,0,211}, port: 8899], [name: Modbus.TCP])
  ```

  """
  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  @doc """
    Stops the GenServer.

    Returns `:ok`.
  """
  def stop(pid) do
    #don't use :normal or the listener won't be stop
    Process.exit(pid, :stop)
  end

  @doc """
  Sends an TCP command.

  Returns `{:ok, response}`.

  ## Example:
  ```
  #write 1 to coil at slave 2 address 3200
  :ok = TCP.cmd(pid, {:wdo, 2, 3200, 1}, 400)
  #write 0 to coil at slave 2 address 3200
  :ok = TCP.cmd(pid, {:wdo, 2, 3200, 0}, 400)
  #read 1 from coil at slave 2 address 3200
  {:ok, [1]} = TCP.cmd(pid, {:rdo, 2, 3200, 1}, 400)
  ```
  """
  def cmd(pid, cmd, timeout) do
    GenServer.call(pid, {:tcp, cmd, timeout})
  end

  ##########################################
  # GenServer Implementation
  ##########################################

  def init(state) do
    config = Enum.into(state, %{ip: {0,0,0,0}, port: 0, timeout: 400})
    {:ok, socket} = :gen_tcp.connect(config.ip, config.port, [:binary, packet: :raw, active: :false], config.timeout)
    {:ok, {socket, 0}}
  end

  def terminate(_reason, _state) do
    #:io.format "terminate ~p ~p ~p ~n", [__MODULE__, reason, state]
  end

  def handle_call({:tcp, cmd, timeout}, _from, {socket, count}) do
    request = Modbus.Request.pack(cmd)
    size =  :erlang.byte_size(request)
    :ok = :gen_tcp.send(socket, <<count::size(16),0,0,size::size(16),request::binary>>)
    {:ok, <<count::size(16),0,0,_size2::size(16),response::binary>>} = :gen_tcp.recv(socket, 0, timeout)
    {:reply, parsetcp(cmd, response), {socket, count + 1}}
  end

  ##########################################
  # Internal Implementation
  ##########################################

  defp parsetcp(cmd, response) do
    {values, <<>>} = Modbus.Response.parse(cmd, response)
    case values do
      nil -> :ok
      _ -> {:ok, values}
    end
  end
end
