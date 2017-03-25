# modbus

Modbus library with TCP Master & Slave implementation.

For Serial RTU see [baud](https://github.com/samuelventura/baud).

Based on:

- http://modbus.org/docs/PI_MBUS_300.pdf
- http://modbus.org/docs/Modbus_Messaging_Implementation_Guide_V1_0b.pdf
- http://modbus.org/docs/Modbus_over_serial_line_V1_02.pdf

## Installation and Usage

1. Add `modbus` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:modbus, "~> 0.3.5"}]
  end
  ```

2. Use as TCP master:

  ```elixir
  #run with: mix opto22
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

  #https://www.h-schmidt.net/FloatConverter/IEEE754.html
  #write -5V (IEEE 754 float) to m3.p0
  #<<-5::float-32>> -> <<192, 160, 0, 0>>
  :ok = Master.exec(pid, {:phr, 1, 24, [0xc0a0, 0x0000]})
  :ok = Master.exec(pid, {:phr, 1, 24, Modbus.IEEE754.to_2_regs(-5.0)})
  #write +5V (IEEE 754 float) to m3.p1
  #<<+5::float-32>> -> <<64, 160, 0, 0>>
  :ok = Master.exec(pid, {:phr, 1, 26, [0x40a0, 0x0000]})
  :ok = Master.exec(pid, {:phr, 1, 26, Modbus.IEEE754.to_2_regs(+5.0)})

  :timer.sleep(20) #outputs settle delay

  #read previous coils as inputs
  {:ok, [0, 1, 1, 0]} = Master.exec(pid, {:ri, 1, 4, 4})

  #read previous analog channels as input registers
  {:ok, [0xc0a0, 0x0000, 0x40a0, 0x0000]} = Master.exec(pid, {:rir, 1, 24, 4})
  {:ok, data} = Master.exec(pid, {:rir, 1, 24, 4})
  [-5.0, +5.0] = Modbus.IEEE754.from_2n_regs(data)
  ```

3. Use as TCP slave:

  ```elixir
  #run with: mix slave
  alias Modbus.Tcp.Slave
  alias Modbus.Tcp.Master

  #start your slave with a shared model
  model = %{ 0x50=>%{ {:c, 0x5152}=>0 } }
  {:ok, spid} = Slave.start_link([model: model])
  #get the assigned tcp port
  {:ok, %{port: port}} = Slave.id(spid)

  #interact with it
  {:ok, mpid} = Master.start_link([ip: {127,0,0,1}, port: port])
  {:ok, [0]} = Master.exec(mpid, {:rc, 0x50, 0x5152, 1})
  ...
  ```

## Roadmap

Future

- [ ] Improve documentation and samples

Version 0.3.5

- [x] Added float helper

Version 0.3.4

- [x] Fixed RTU CRC endianess

Version 0.3.3

- [x] Shared model slave implementation

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
