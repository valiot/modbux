# modbus

Modbus library with TCP implementation.

- For RTU see [baud](https://github.com/samuelventura/baud).
- For TCP-to-RTU translation see [baud](https://github.com/samuelventura/baud) or [serex](https://github.com/samuelventura/serex).

Based on:

- http://modbus.org/docs/PI_MBUS_300.pdf
- http://modbus.org/docs/Modbus_Messaging_Implementation_Guide_V1_0b.pdf

## Installation and Usage

1. Add `modbus` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:modbus, "~> 0.2.0"}]
  end
  ```

2. Generic use as a pure packing and parsing library

  ```elixir
  alias Modbus.Request
  alias Modbus.Response
  #read 1 coil from slave 5 address 2300
  cmd = {:rc, 5, 2300, 1}
  req = Request.pack(cmd)
  #send request thru a serial (RTU, ASCII) or socket (TCP) channel
  res = channel.send(req)
  {[1], tail} = Response.parse(cmd, res)
  ```

3. Use as TCP master

  ```elixir
  alias Modbus.Master
  #start master TCP server
  {:ok, pid} = Master.start_link([ip: {10,77,0,211}, port: 8899])
  #force 0 to coil at slave 1 address 3000
  :ok = Master.tcp(pid, {:fc, 1, 3000, 0}, 400)
  #read 0 from coil at slave 1 address 3000
  {:ok, [0]} = Master.tcp(pid, {:rc, 1, 3000, 1}, 400)
  #force 10 to coils at slave 1 address 3000 to 3001
  :ok = Master.tcp(pid, {:fc, 1, 3000, [1, 0]}, 400)
  #read 10 from coils at slave 1 address 3000 to 3001
  {:ok, [1, 0]} = Master.tcp(pid, {:rc, 1, 3000, 2}, 400)
  #preset 55AA to holding register at slave 1 address 3300
  :ok = Master.tcp(pid, {:phr, 1, 3300, 0x55AA}, 400)
  #read 55AA from holding register at slave 1 address 3300 to 3301
  {:ok, [0x55AA]} = Master.tcp(pid, {:rhr, 1, 3300, 1}, 400)
  ```

## Roadmap

Version 0.3.0

- [ ] Modbus TCP slave

Version 0.2.0

- [x] Updated documentation
- [x] Renamed commands to match spec wording

Version 0.1.0

- [x] Modbus TCP master
- [x] Request/response packet builder and parser
- [x] Device model to emulate slave interaction
