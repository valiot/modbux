# modbus

Modbus library with TCP implementation.

- For Serial RTU see [baud](https://github.com/samuelventura/baud).
- For TCP-to-RTU translation see [baud](https://github.com/samuelventura/baud)

Based on:

- http://modbus.org/docs/PI_MBUS_300.pdf
- http://modbus.org/docs/Modbus_Messaging_Implementation_Guide_V1_0b.pdf
- http://modbus.org/docs/Modbus_over_serial_line_V1_02.pdf

## Installation and Usage

1. Add `modbus` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:modbus, "~> 0.3.0"}]
  end
  ```

2. Generic use as a pure packing and parsing library

  ```elixir
  alias Modbus.Request
  alias Modbus.Response
  #read 1 from input at slave 1 address 0
  cmd = {:ri, 1, 0, 2}
  req = Request.pack(cmd)
  #send request thru a serial or socket channel
  res = channel.send(req)
  [1, 0] = Response.parse(cmd, res)
  ```

3. Use as TCP master

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

## Roadmap

Version 0.3.0

- [ ] Modbus TCP slave
- [x] API breaking changes

Version 0.2.0

- [x] Updated documentation
- [x] Renamed commands to match spec wording

Version 0.1.0

- [x] Modbus TCP master
- [x] Request/response packet builder and parser
- [x] Device model to emulate slave interaction
