defmodule Modbus.Master do
  @moduledoc """
  TCP Master module.

  ## Example

  ```elixir
  alias Modbus.Master

  #opto22 rack configured as follows
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

  {:ok, pid} = Master.start_link([ip: {10,77,0,2}, port: 502])

  #read 1 from input at slave 1 address 0 (m0.p0)
  {:ok, [1]} = Master.tcp(pid, {:ri, 1, 0, 1})
  #read 0 from input at slave 1 address 1 (m0.p1)
  {:ok, [0]} = Master.tcp(pid, {:ri, 1, 1, 1})
  #read both previous inputs at once
  {:ok, [1, 0]} = Master.tcp(pid, {:ri, 1, 0, 2})

  #turn off coil at slave 1 address 6 (m1.p2)
  :ok = Master.tcp(pid, {:fc, 1, 6, 0})
  :timer.sleep(50) #let output settle
  #read 0 from input at slave 1 address 2 (m0.p2)
  {:ok, [0]} = Master.tcp(pid, {:ri, 1, 2, 1})

  #turn on coil at slave 1 address 7 (m1.p3)
  :ok = Master.tcp(pid, {:fc, 1, 7, 1})
  :timer.sleep(50) #let output settle
  #read 1 from input at slave 1 address 3 (m0.p3)
  {:ok, [1]} = Master.tcp(pid, {:ri, 1, 3, 1})
  ```
  """
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Tcp

  @to 2000

  ##########################################
  # Public API
  ##########################################

  @doc """
  Starts the Server.

  `state` is a keyword list where:
  `ip` is the internet address to connect to.
  `port` is the tcp port number to connect to.
  `timeout` is the connection timeout.

  Returns `{:ok, pid}`.

  ## Example

  ```elixir
  Modbus.Master.start_link([ip: {10,77,0,2}, port: 502, timeout: 2000])
  ```

  """
  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  @doc """
  Stops the Server.
  """
  def stop(pid) do
    Agent.stop(pid)
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
  def tcp(pid, cmd, timeout \\ @to) do
    Agent.get_and_update(pid, fn {socket, transid} ->
      request = Request.pack(cmd)
      :ok = :gen_tcp.send(socket, Tcp.wrap(request, transid))
      {:ok, data} = :gen_tcp.recv(socket, 0, timeout)
      response = Tcp.unwrap(data, transid)
      values = Response.parse(cmd, response)
      case values do
        nil -> {:ok, {socket, transid + 1}}
        _ -> {{:ok, values}, {socket, transid + 1}}
      end
    end)
  end

  defp init(params) do
    ip = Keyword.fetch!(params, :ip)
    port = Keyword.fetch!(params, :port)
    timeout = Keyword.get(params, :timeout, @to)
    {:ok, socket} = :gen_tcp.connect(ip, port,
      [:binary, packet: :raw, active: :false], timeout)
    {socket, 0}
  end

end
