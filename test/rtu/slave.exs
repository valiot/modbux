defmodule RtuSlave do
  use ExUnit.Case
  alias Circuits.UART

  @moduledoc """
  These tests only runs if 'tty0tty' is installed in the host computer.
  """
  test "Slave test for fc => [1, 2, 3, 4, 5, 6, 15, 16]" do
    # Raw initialization.
    # RingLogger.attach()
    {:ok, m_pid} = UART.start_link()

    UART.open(m_pid, "tnt0", speed: 115_200, framing: {Modbux.Rtu.Framer, behavior: :master})

    model = %{
      80 => %{
        {:c, 1} => 1,
        {:c, 2} => 0,
        {:i, 1} => 1,
        {:i, 2} => 1,
        {:ir, 1} => 1,
        {:ir, 2} => 0,
        {:hr, 1} => 0,
        {:hr, 2} => 1
      }
    }

    {:ok, s_pid} = Modbux.Rtu.Slave.start_link(tty: "tnt1", model: model, active: true)

    # Master Requests.
    # Read Coil Status (FC=01)
    fc = <<80, 1, 0, 1, 0, 1, 161, 139>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:rc, 80, 1, 1}}}
    # master
    assert_receive {circuits_uart, "tnt0", <<80, 1, 1, 1, 128, 180>>}

    # Read Input Status (FC=02)
    fc = <<80, 2, 0, 1, 0, 1, 229, 139>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:ri, 80, 1, 1}}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 2, 1, 1, 112, 180>>}

    # Read Holding Registers (FC=03)
    fc = <<80, 3, 0, 1, 0, 1, 216, 75>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:rhr, 80, 1, 1}}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 3, 2, 0, 0, 69, 136>>}

    # Read Input Registers (FC=04)
    fc = <<80, 4, 0, 1, 0, 1, 109, 139>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:rir, 80, 1, 1}}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 4, 2, 0, 1, 133, 60>>}

    # Force Single Coil (FC=05)
    fc = <<80, 5, 0, 1, 0, 0, 145, 139>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:fc, 80, 1, 0}}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 5, 0, 1, 0, 0, 145, 139>>}
    assert Modbux.Rtu.Slave.get_db(s_pid)[80][{:c, 1}] == 0

    # Preset Single Register (FC=06)
    fc = <<80, 6, 0, 1, 0, 0, 213, 139>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:phr, 80, 1, 0}}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 6, 0, 1, 0, 0, 213, 139>>}
    assert Modbux.Rtu.Slave.get_db(s_pid)[80][{:hr, 1}] == 0

    # # Force Multiple Coils (FC=15)
    fc = <<80, 15, 0, 1, 0, 2, 1, 2, 166, 102>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:fc, 80, 1, [0, 1]}}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 15, 0, 1, 0, 2, 136, 75>>}
    assert Modbux.Rtu.Slave.get_db(s_pid)[80][{:c, 1}] == 0
    assert Modbux.Rtu.Slave.get_db(s_pid)[80][{:c, 2}] == 1

    # Preset Multiple Registers (FC=16)
    fc = <<80, 16, 0, 1, 0, 2, 4, 0, 0, 0, 1, 246, 94>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:phr, 80, 1, [0, 1]}}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 16, 0, 1, 0, 2, 29, 137>>}
    assert Modbux.Rtu.Slave.get_db(s_pid)[80][{:hr, 1}] == 0
    assert Modbux.Rtu.Slave.get_db(s_pid)[80][{:hr, 2}] == 1

    # Exception in bus from other slaves
    excep = <<0x0A, 0x81, 0x02, 0xB0, 0x53>>
    UART.write(m_pid, excep)
    # slave
    refute_receive {:modbus_rtu, {:slave_request, {:error, 10, 129, 2}}}

    # Return exception for invalid address
    fc = <<80, 1, 7, 210, 0, 1, 81, 6>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_error, {:rc, 80, 2002, 1}, :eaddr}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 129, 2, 144, 64>>}

    # Returns exception for invalid function code
    fc = <<80, 11, 7>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_error, "P\v", :einval}}
    # master
    assert_receive {:circuits_uart, "tnt0", <<80, 139, 1, 214, 225>>}

    # Crc
    fc = <<80, 1, 7, 210, 0, 1, 81, 7>>
    UART.write(m_pid, fc)
    # slave
    assert_receive {:modbus_rtu, {:slave_error, "CRC Error", :ecrc}}
    # master
    refute_receive {:circuits_uart, "tnt0", <<80, 129, 2, 144, 64>>}

    # Slave request function
    # sets
    assert Modbux.Rtu.Slave.request(s_pid, {:phr, 80, 1, [1, 0]}) == nil
    # reads
    assert Modbux.Rtu.Slave.request(s_pid, {:rhr, 80, 1, 1}) == [1]
  end
end
