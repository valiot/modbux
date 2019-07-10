defmodule RtuFramer do
  use ExUnit.Case
  alias Circuits.UART

  @moduledoc """
  These tests only runs if 'tty0tty' is installed in the host computer.
  """
  test "Framer test for fc => [1, 2, 3, 4, 5, 6, 15, 16]" do
    # Raw initialization.
    # RingLogger.attach()
    {:ok, m_pid} = UART.start_link()
    {:ok, s_pid} = UART.start_link()

    UART.open(m_pid, "tnt0", speed: 115_200, framing: {Modbus.Rtu.Framer, behavior: :master})
    UART.open(s_pid, "tnt1", speed: 115_200, framing: {Modbus.Rtu.Framer, behavior: :slave})

    # Master Requests.
    # Read Coil Status (FC=01)
    fc = <<0x11, 0x01, 0x00, 0x13, 0x00, 0x25, 0x0E, 0x84>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Read Input Status (FC=02)
    fc = <<0x11, 0x02, 0x00, 0xC4, 0x00, 0x16, 0xBA, 0xA9>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Read Holding Registers (FC=03)
    fc = <<0x11, 0x03, 0x00, 0x6B, 0x00, 0x03, 0x76, 0x87>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Read Input Registers (FC=04)
    fc = <<0x11, 0x04, 0x00, 0x08, 0x00, 0x01, 0xB2, 0x98>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Force Single Coil (FC=05)
    fc = <<0x11, 0x05, 0x00, 0xAC, 0xFF, 0x00, 0x4E, 0x8B>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Preset Single Register (FC=06)
    fc = <<0x11, 0x06, 0x00, 0x01, 0x00, 0x03, 0x9A, 0x9B>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Force Multiple Coils (FC=15)
    fc = <<0x11, 0x0F, 0x00, 0x13, 0x00, 0x0A, 0x02, 0xCD, 0x01, 0xBF, 0x0B>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Preset Multiple Registers (FC=16)
    fc = <<0x11, 0x10, 0x00, 0x01, 0x00, 0x02, 0x04, 0x00, 0x0A, 0x01, 0x02, 0xC6, 0xF0>>
    UART.write(m_pid, fc)
    assert_receive {circuits_uart, "tnt1", fc}

    # Exception
    excep = <<0x0A, 0x81, 0x02, 0xB0, 0x53>>
    UART.write(m_pid, excep)
    assert_receive {circuits_uart, "tnt1", excep}

    # Server Response.
    # Read Coil Status (FC=01)
    resp = <<0x11, 0x01, 0x05, 0xCD, 0x6B, 0xB2, 0x0E, 0x1B, 0x45, 0xE6>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}

    # Read Input Status (FC=02)
    resp = <<0x11, 0x02, 0x03, 0xAC, 0xDB, 0x35, 0x20, 0x18>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}

    # Read Holding Registers (FC=03)
    resp = <<0x11, 0x03, 0x06, 0xAE, 0x41, 0x56, 0x52, 0x43, 0x40, 0x49, 0xAD>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}

    # Read Input Registers (FC=04)
    resp = <<0x11, 0x04, 0x02, 0x00, 0x0A, 0xF8, 0xF4>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}

    # Force Single Coil (FC=05)
    resp = <<0x11, 0x05, 0x00, 0xAC, 0xFF, 0x00, 0x4E, 0x8B>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}

    # Preset Single Register (FC=06)
    resp = <<0x11, 0x06, 0x00, 0x01, 0x00, 0x03, 0x9A, 0x9B>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}

    # Force Multiple Coils (FC=15)
    resp = <<0x11, 0x0F, 0x00, 0x13, 0x00, 0x0A, 0x26, 0x99>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}

    # Preset Multiple Registers (FC=16)
    resp = <<0x11, 0x10, 0x00, 0x01, 0x00, 0x02, 0x12, 0x98>>
    UART.write(s_pid, resp)
    assert_receive {circuits_uart, "tnt0", resp}
  end
end
