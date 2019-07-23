defmodule RtuMaster do
  use ExUnit.Case

  @moduledoc """
  These tests only runs if 'tty0tty' is installed in the host computer.
  """
  test "Master test for fc => [1, 2, 3, 4, 5, 6, 15, 16]" do
    RingLogger.attach()
    {:ok, m_pid} = Modbus.Rtu.Master.start_link(tty: "tnt0")

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

    {:ok, s_pid} = Modbus.Rtu.Slave.start_link(tty: "tnt1", model: model, active: true)

    assert model == Modbus.Rtu.Slave.get_db(s_pid)
    # Master Requests.
    # Read Coil Status (FC=01)
    resp = Modbus.Rtu.Master.request(m_pid, {:rc, 80, 1, 1})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:rc, 80, 1, 1}}}
    # master
    assert resp == {:ok, [1]}

    # Read Input Status (FC=02)
    resp = Modbus.Rtu.Master.request(m_pid, {:ri, 80, 1, 1})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:ri, 80, 1, 1}}}
    # master
    assert resp == {:ok, [1]}

    # Read Holding Registers (FC=03)
    resp = Modbus.Rtu.Master.request(m_pid, {:rhr, 80, 1, 2})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:rhr, 80, 1, 2}}}
    # master
    assert resp == {:ok, [102, 103]}

    # # Read Input Registers (FC=04)
    resp = Modbus.Rtu.Master.request(m_pid, {:rir, 80, 1, 1})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:rir, 80, 1, 1}}}
    # master
    assert resp == {:ok, [0]}

    # Force Single Coil (FC=05)
    resp = Modbus.Rtu.Master.request(m_pid, {:fc, 80, 1, 0})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:fc, 80, 1, 0}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:c, 1}] == 0

    # backward
    resp = Modbus.Rtu.Master.request(m_pid, {:fc, 80, 1, 1})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:fc, 80, 1, 1}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:c, 1}] == 1

    # Preset Single Register (FC=06)
    resp = Modbus.Rtu.Master.request(m_pid, {:phr, 80, 1, 10})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:phr, 80, 1, 10}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:hr, 1}] == 10

    # backward
    resp = Modbus.Rtu.Master.request(m_pid, {:phr, 80, 1, 102})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:phr, 80, 1, 102}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:hr, 1}] == 102

    # Force Multiple Coils (FC=15)
    resp = Modbus.Rtu.Master.request(m_pid, {:fc, 80, 1, [0, 1]})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:fc, 80, 1, [0, 1]}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:c, 1}] == 0
    assert model[80][{:c, 2}] == 1

    # backward
    resp = Modbus.Rtu.Master.request(m_pid, {:fc, 80, 1, [1, 0]})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:fc, 80, 1, [1, 0]}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:c, 1}] == 1
    assert model[80][{:c, 2}] == 0

    # Preset Multiple Registers (FC=16)
    resp = Modbus.Rtu.Master.request(m_pid, {:phr, 80, 1, [0, 1]})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:phr, 80, 1, [0, 1]}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:hr, 1}] == 0
    assert model[80][{:hr, 2}] == 1

    # backward
    resp = Modbus.Rtu.Master.request(m_pid, {:phr, 80, 1, [102, 103]})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:phr, 80, 1, [102, 103]}}}
    # master
    assert resp == :ok

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:hr, 1}] == 102
    assert model[80][{:hr, 2}] == 103

    # Return exception for invalid address
    resp = Modbus.Rtu.Master.request(m_pid, {:phr, 80, 2, [102, 103]})
    # slave
    assert_receive {:modbus_rtu, {:slave_error, {:phr, 80, 2, 'fg'}, :eaddr}}
    # master
    assert resp == {:error, :eaddr}

    model = Modbus.Rtu.Slave.get_db(s_pid)

    assert model[80][{:hr, 1}] == 102
    assert model[80][{:hr, 2}] == 103

    # Return CRC error
    # bad crc
    assert Modbus.Rtu.Slave.raw_write(s_pid, <<80, 4, 2, 0, 1, 133, 61>>)
    resp = Modbus.Rtu.Master.read(m_pid)

    assert resp == {:error, :ecrc}

    Modbus.Rtu.Master.configure(m_pid, active: true)

    # Active mode.
    # Read Coil Status (FC=01)
    resp = Modbus.Rtu.Master.request(m_pid, {:rc, 80, 1, 1})
    # slave
    assert_receive {:modbus_rtu, {:slave_request, {:rc, 80, 1, 1}}}
    # master
    assert resp == :ok
    assert_receive {:modbus_rtu, {:slave_response, {:rc, 80, 1, 1}, [1]}}
  end
end
