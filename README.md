# modbus

Modbus for elixir.

Based on http://modbus.org/docs/PI_MBUS_300.pdf

## Installation and Usage

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `modbus` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:modbus, "~> 0.1.0"}]
    end
    ```

  2. Use it:

    ```elixir
    alias Modbus.Request
    alias Modbus.Response
    #read one coil from slave 5 address 2300
    cmd = {:rdo, 5, 2300, 1}
    req = Request.pack(cmd)
    #send request thru a serial (RTU, ASCII) or socket (TCP) channel
    res = channel.send(req)
    {[1], tail} = res.parse(cmd, res)
    ```

## Roadmap

Version 0.1.0

- [ ] Modbus TCP master
- [ ] Modbus TCP slave
- [x] Request/response packet builder and parser
- [x] Device model to emulate slave interaction
