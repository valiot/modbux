defmodule Modbus.Tcp.Server.Supervisor do
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  def start_child(sup_pid,module, args) do
    DynamicSupervisor.start_child(sup_pid, {module, args})
  end

  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
