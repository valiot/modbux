defmodule Modbus.Tcp.Client do
  use GenServer
  alias Modbus.Tcp.Client
  #defaults
  @timeout 2000
  @port 502
  @ip {0,0,0,0}
  @active false

  defstruct ip: nil,
            tcp_port: nil,
            port: nil,
            timeout: @timeout,
            active: nil,
            name: nil,
            status: nil


  @type client_option ::
          {:active, boolean}
          | {:port, non_neg_integer}
          | {:ip, tuple}
          | {:id, :name | :pid}
          | {:timeout, non_neg_integer}

  @doc """
  Start up a Modbus Client GenServer.
  """
  @spec start_link([term]) :: {:ok, pid} | {:error, term}
  def start_link(args \\ [],opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Stop the Modbus Client GenServer.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

   @doc """
  Connect the Modbus Client.
  """
  @spec connect(GenServer.server(), [client_option]) :: :ok | {:error, term}
  def connect(pid, opts \\ []) do
    GenServer.call(pid, {:connect, opts})
  end

  @doc """
  Close the Modbus Client. The GenServer continues to run so that a port can
  be opened again.
  """
  @spec close(GenServer.server()) :: :ok | {:error, term}
  def close(pid) do
    GenServer.call(pid, :close)
  end



  @doc """
  Change the Modbus Client configuration after `connect` has been called. See
  `open/3` for the valid options.
  """
  @spec configure(GenServer.server(), [client_option]) :: :ok | {:error, term}
  def configure(pid, opts) do
    GenServer.call(pid, {:configure, opts})
  end

  @doc """
  Get the configuration of the Modbus Client.
  """
  @spec configuration(GenServer.server()) :: {binary() | :closed, [client_option]}
  def configuration(pid) do
    GenServer.call(pid, :configuration)
  end

  def init(args) do
    port = args[:port] || @port
    ip = args[:ip] || @ip
    timeout = args[:timeout] || @timeout
    status = :standby
    active = args[:active] || @active
    state = %Client{ip: ip, tcp_port: port, timeout: timeout, status: status, active: active}
    {:ok, state}
  end

  def handle_call(_from_pid, {:connect, opts}, state) do

    result = :gen_tcp.connect(state.ip, state.port, [:binary, packet: :raw, active: state.active], state.timeout)

    case result do
      {:ok, socket} ->
        new_state = %{state | status: :connected, port: socket}
        {:replay, new_state}

      {:error, reason} ->
        {:replay, reason, state}
    end

  end
end
