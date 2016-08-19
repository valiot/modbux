defmodule Modbus.Master do
  @moduledoc """
  Server module to handle a socket connection.
  """
  use GenServer
  alias Modbus.Request
  alias Modbus.Response

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

  `timeout` is the connection timeout.

  Returns `{:ok, pid}`.

  ## Example

  ```elixir
  Modbus.Master.start_link([ip: {10,77,0,211}, port: 8899, timeout: 800])
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

  def tcp(pid, cmd, timeout) do
    request = Request.pack(cmd)
    response = GenServer.call(pid, {:reqres, request, timeout})
    {values, <<>>} = Response.parse(cmd, response)
    case values do
      nil -> :ok
      _ -> {:ok, values}
    end
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

  def handle_call({:reqres, request, timeout}, _from, {socket, count}) do
    size =  :erlang.byte_size(request)
    :ok = :gen_tcp.send(socket, <<count::size(16),0,0,size::size(16),request::binary>>)
    {:ok, <<count::size(16),0,0,ressize::size(16),response::binary>>} = :gen_tcp.recv(socket, 0, timeout)
    ^ressize = :erlang.byte_size(response)
    {:reply, response, {socket, count + 1}}
  end

end
