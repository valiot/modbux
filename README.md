# modbus

Modbus library with TCP implementation.

- For Serial RTU see [baud](https://github.com/samuelventura/baud).
- For TCP-to-RTU translation see [forward](https://github.com/samuelventura/forward).

Based on:

- http://modbus.org/docs/PI_MBUS_300.pdf
- http://modbus.org/docs/Modbus_Messaging_Implementation_Guide_V1_0b.pdf
- http://modbus.org/docs/Modbus_over_serial_line_V1_02.pdf

## Installation and Usage

1. Add `modbus` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:modbus, "~> 0.3.1"}]
  end
  ```

2. Generic use as a pure packing and parsing library

  ```elixir
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Tcp
  #read 1 from input at slave 1 address 0
  cmd = {:ri, 1, 0, 2}
  req = Request.pack(cmd)
  wreq = Tcp.wrap(req, transid)
  #send wrapped request thru a serial or socket channel
  wres = :channel.send_and_receive(wreq)
  res = Tcp.unwrap(wres, transid)
  [1, 0] = Response.parse(cmd, res)
  ```

3. Use as TCP master

  ```elixir
  alias Modbus.Tcp.Master

  # opto22 rack configured as follows
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
  # m2 - 2p analog input (-10V to +10V)
  #  p0 - m3.p0
  #  p1 - m3.p1
  # m3 - 2p analog output (-10V to +10V)
  #  p0 - m2.p0
  #  p1 - m2.p1

  {:ok, pid} = Master.start_link([ip: {10,77,0,2}, port: 502])

  #turn off m1.p0
  :ok = Master.exec(pid, {:fc, 1, 4, 0})
  #turn on m1.p1
  :ok = Master.exec(pid, {:fc, 1, 5, 1})
  #alternate m1.p2 and m1.p3
  :ok = Master.exec(pid, {:fc, 1, 6, [1, 0]})

  #write -5V (IEEE 754 float) to m3.p0
  :ok = Master.exec(pid, {:phr, 1, 24, [0xc0a0, 0x0000]})
  #write +5V (IEEE 754 float) to m3.p1
  :ok = Master.exec(pid, {:phr, 1, 26, [0x40a0, 0x0000]})

  :timer.sleep(20) #outputs settle delay

  #read previous coils as inputs
  {:ok, [0, 1, 1, 0]} = Master.exec(pid, {:ri, 1, 4, 4})

  #read previous analog channels as input registers
  {:ok, [0xc0a0, 0x0000, 0x40a0, 0x0000]} = Master.exec(pid, {:rir, 1, 24, 4})
  ```

## Roadmap

Version 0.3.3

- [ ] Shared model slave implementation

Version 0.3.2

- [x] Added request length prediction
- [x] Refactored namespaces to avoid baud clash
- [x] Tcp master api updated to match baud rtu master api

Version 0.3.1

- [x] Added master/slave test for each code
- [x] Added response length prediction
- [x] Added a couple of helpers to tcp and rtu api
- [x] A reference-only tcp slave added in test helper

Version 0.3.0

- [x] Modbus TCP slave: wont fix, to be implemented as forward plugin
- [x] API breaking changes

Version 0.2.0

- [x] Updated documentation
- [x] Renamed commands to match spec wording

Version 0.1.0

- [x] Modbus TCP master
- [x] Request/response packet builder and parser
- [x] Device model to emulate slave interaction
