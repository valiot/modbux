<br>
<div align="center">
  <img src="assets/valiot-logo-blue.png" alt="Valiot Logo" width="192" height="57" />
</div>
<br>  

# Modbux

Modbux is a library for network and serial Modbus communications. 

This library currently supports behaviors for TCP (Client & Server) and RTU (Master & Slave) protocols.

## Index

* [Features](#features)

* [Installation](#installation)

* [Usage](#usage)
    * [Modbus RTU](#Slave)
    * [Modbus TCP](#Server)
    * [Helpers](#Helpers)

* [Documentation](#documentation)

* [Contributing](#contributing)

* [License](#License)

* [TODO](#todo)

## Features

The following list is the current supported protocols/behaviors and helpers:

- Modbus RTU:
  - Master
  - Slave
  - Framer

- Modbus TCP:
  - Client
  - Server

- Helpers:
  - IEEE754 Float support
  - Endianess


## Installation

The package can be installed by adding `modbux` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:modbux, "~> 0.1.0"}
  ]
end
```

## Usage
***
### Modbus RTU

Modbus RTU is an open serial protocol derived from the Master/Slave architecture originally developed by Modicon. This protocol primarily uses an RS-232 or RS-485 serial interfaces for communications.

#### Slave

To start a Modbus RTU Slave process use `start_link/1`.

The following options are available:
- `tty` - defines the serial port to spawn the Slave.
- `gen_opts` - defines extra options for the Genserver OTP configuration.
- `uart_opts` - defines extra options for the UART configuration.
- `model` - defines the DB initial state.
- `active` - (`true` or `false`) enable/disable DB updates notifications (mailbox).

The messages (when active mode is `true`) have the following form:
```elixir
  {:modbus_rtu, {:slave_request, payload}}
```
or

```elixir
  {:modbus_rtu, {:slave_error, payload, reason}}
```

The following are some reasons:

* `:ecrc`  - corrupted message (invalid crc).
* `:einval`  - invalid function.
* `:eaddr`  - invalid memory address requested.

#### Model (DB)

The model or data base (DB) defines the slave/server memory map, the DB is defined by the following syntax:
```elixir
%{slave_id => %{{memory_type, address_number} => value}}
```
where:
* `slave_id` - specify a unique unit address from 1 to 247.
* `memory_type` - specify the memory between:
    * `:c` - Discrete Output Coils.
    * `:i` - Discrete Input Contacts.
    * `:ir` - Analog Input Registers.
    * `:hr` - Analog Output Registers.
* `address_number` - specify the memory address.
* `value` - the current value from that memory.

### Example
```elixir
# DB inital state
model = %{
    80 => %{
      {:c, 1} => 1,
      {:c, 2} => 0,
      {:i, 1} => 1,
      {:i, 2} => 1,
      {:ir, 1} => 0,
      {:ir, 2} => 1,
      {:hr, 1} => 102,
      {:hr, 2} => 103
    }
  }
# Starts the Slave at "ttyUSB0"
{:ok, s_pid} = Modbux.Rtu.Slave.start_link(tty: "ttyUSB0", model: model, active: true)
```
if needed, the Slave DB can be modified in runtime with elixir code by using `request/2`,
a `cmd` must be used to update the DB, the `cmd` is a 4 elements tuple, as follows:
  - `{:rc, slave, address, count}` read `count` coils.
  - `{:ri, slave, address, count}` read `count` inputs.
  - `{:rhr, slave, address, count}` read `count` holding registers.
  - `{:rir, slave, address, count}` read `count` input registers.
  - `{:fc, slave, address, value}` force single coil.
  - `{:phr, slave, address, value}` preset single holding register.
  - `{:fc, slave, address, values}` force multiple coils.
  - `{:phr, slave, address, values}` preset multiple holding registers.

#### Master

To start a Modbus RTU Master process use `start_link/1`.

The following options are available:

  * `tty` - defines the serial port to spawn the Master.
  * `timeout` - defines slave timeout.
  * `active` - (`true` or `false`) specifies whether data is received as
      messages (mailbox) or by calling `request/2`.
  * `gen_opts` - defines extra options for the Genserver OTP configuration.
  * `uart_opts` - defines extra options for the UART configuration (defaults:
        [speed: 115200, rx_framing_timeout: 1000]).

The messages (when active mode is true) have the following form:
```elixir
  {:modbus_rtu, {:slave_response, cmd, values}}
```
or
```elixir
  {:modbus_rtu, {:slave_error, payload, reason}}
```
The following are some reasons:

  * `:ecrc`  - corrupted message (invalid crc).
  * `:einval`  - invalid function.
  * `:eaddr`  - invalid memory address requested.

use `request/2` to send a `cmd` (command) to a Modbus RTU Slave.

### Example

```elixir
# Starts the Master at "ttyUSB1" (in the example is connected to ttyUSB1)
{:ok, m_pid} = Modbux.Rtu.Master.start_link(tty: "ttyUSB1")
# Read 2 holding registers at 1 (memory address) from the slave 80
resp = Modbux.Rtu.Master.request(m_pid, {:rhr, 80, 1, 2})
# resp == {:ok, [102, 103]}
```

### Modbux TCP

Modbus TCP (also Modbus TCP/IP) is simply the Modbus RTU protocol with a TCP interface that runs on a network.

#### Server

To start a Modbus TCP Server process use `start_link/1`.

The following options are available:

  * `port` - is the Modbux TCP Server tcp port number.
  * `timeout` - is the connection timeout.
  * `model` - defines the DB initial state.
  * `sup_otps` - server supervisor OTP options.
  * `active` - (`true` or `false`) enable/disable DB updates notifications (mailbox).

The messages (when active mode is true) have the following form:
```elixir
  {:modbus_tcp, {:slave_request, payload}}
```

### Example

```elixir
# DB initial state
model = %{80 => %{{:c, 20818} => 0, {:hr, 20818} => 0}}
# Starts the Server at tcp port: 2000
Modbux.Tcp.Server.start_link(model: model, port: 2000)
```

#### Client 

To start a Modbus TCP Client process use `start_link/1`.

The following options are available:

  * `ip` - is the internet address of the desired Modbux TCP Server.
  * `tcp_port` - is the desired Modbux TCP Server tcp port number.
  * `timeout` - is the connection timeout.
  * `active` - (`true` or `false`) specifies whether data is received as
      messages (mailbox) or by calling `confirmation/1` each time `request/2` is called.

The messages (when active mode is true) have the following form:

```elixir
  {:modbus_tcp, cmd, values}
```

to connect to a Modbus TCP Server `connect/1`.

Use `request/2` to send a `cmd` (command) to a Modbus TCP Server and `confirmation/1` to parse the server response.

### Example

```elixir
# Starts the Client that will connect to a Server with tcp port: 2000
{:ok, cpid} = Modbux.Tcp.Client.start_link(ip: {127,0,0,1}, port: 2000, timeout: 2000, active: true)
# Connect to the Server
Modbux.Tcp.Client.connect(cpid)
# Read 1 coil at 20818 from the device 80
Modbux.Tcp.Client.request(cpid, {:rc, 0x50, 20818, 1})
# Parse the Server response
resp = Modbux.Tcp.Client.confirmation(cpid) 
# resp == {:ok, [0]}
```


### Helpers

#### IEEE754 Float

Several modbus register use IEEE754 float format, therefore this library also provides functions to encode and decode data.

### Example

```elixir
  # Encode
  +5.0 = Modbux.IEEE754.from_2_regs(0x40a0, 0x0000, :be)
  [-5.0, +5.0] = Modbux.IEEE754.from_2n_regs([0xc0a0, 0x0000, 0x40a0, 0x0000], :be)
  # Decode
  [0xc0a0, 0x0000] = Modbux.IEEE754.to_2_regs(-5.0)
  [0xc0a0, 0x0000, 0x40a0, 0x0000] = Modbux.IEEE754.to_2n_regs([-5.0, +5.0])
```

Based on https://www.h-schmidt.net/FloatConverter/IEEE754.html.

#### Endianess

Depending on the device / server the data can be encoded with different types of endianess, therefore this library also provides functions to encode data.

### Example

```elixir
  # Encode
  2.3183081793789774e-41 = Modbux.IEEE754.from_2_regs(0x40a0, 0x0000, :le)
  [6.910082987278538e-41, 2.3183081793789774e-41] = Modbux.IEEE754.from_2n_regs([0xc0a0, 0x0000, 0x40a0, 0x0000], :le)
```


Good to know:
- [Erlang default endianess is BIG](http://erlang.org/doc/programming_examples/bit_syntax.html#Defaults)
- [MODBUS default endianess is BIG (p.34)](http://modbus.org/docs/PI_MBUS_300.pdf)
- [MODBUS CRC endianess is LITTLE (p.16)](http://modbus.org/docs/PI_MBUS_300.pdf)


## Documentation
The docs can be found at [https://hexdocs.pm/modbux](https://hexdocs.pm/modbux).

Based on:

- http://modbus.org/docs/PI_MBUS_300.pdf
- http://modbus.org/docs/Modbux_Messaging_Implementation_Guide_V1_0b.pdf
- http://modbus.org/docs/Modbux_over_serial_line_V1_02.pdf
- http://www.simplymodbus.ca/index.html

## Contributing
  * Fork our repository on github.
  * Fix or add what is needed.
  * Commit to your repository.
  * Issue a github pull request (fill the PR template).

## License
  See [LICENSE](./LICENSE).

## TODO
  * Add Modbux ASCII.
  * Add Modbux UDP.
  * Add more examples.
  * Improve error handling.





