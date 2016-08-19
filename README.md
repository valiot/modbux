# modbus

Modbus for Elixir with a TCP implementation.

***To be used by ```baud``` and ```serex```***

Based on http://modbus.org/docs/PI_MBUS_300.pdf

## Installation and Usage

1. Add `modbus` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:modbus, "~> 0.1.0"}]
  end
  ```

2. Generic use as a pure packing and parsing library

  ```elixir
  alias Modbus.Request
  alias Modbus.Response
  #read 1 coil from slave 5 address 2300
  cmd = {:rdo, 5, 2300, 1}
  req = Request.pack(cmd)
  #send request thru a serial (RTU, ASCII) or socket (TCP) channel
  res = channel.send(req)
  {[1], tail} = Response.parse(cmd, res)
  ```

3. Use as TCP master

  ```elixir
  alias Modbus.Master
  Master.start_link([ip: {10,77,0,211}, port: 8899])
  #write 1 to coil at slave 2 address 3200
  :ok = Master.tcp(pid, {:wdo, 2, 3200, 1}, 400)
  #write 0 to coil at slave 2 address 3200
  :ok = Master.tcp(pid, {:wdo, 2, 3200, 0}, 400)
  #read 1 from coil at slave 2 address 3200
  {:ok, [1]} = Master.tcp(pid, {:rdo, 2, 3200, 1}, 400)
  ```

## Roadmap

Version 0.2.0

- [ ] Modbus TCP slave
- [ ] Complete documentation

Version 0.1.0

- [x] Modbus TCP master
- [x] Request/response packet builder and parser
- [x] Device model to emulate slave interaction
