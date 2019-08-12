defmodule Modbux.Tcp.Server.Supervisor do
  @moduledoc """
  Spawns and supervises each Modbus Client handler.
  """
  use DynamicSupervisor

  @spec start_link([
          {:debug, [:log | :statistics | :trace | {any, any}]}
          | {:hibernate_after, :infinity | non_neg_integer}
          | {:name, atom | {:global, any} | {:via, atom, any}}
          | {:spawn_opt,
             :link
             | :monitor
             | {:fullsweep_after, non_neg_integer}
             | {:min_bin_vheap_size, non_neg_integer}
             | {:min_heap_size, non_neg_integer}
             | {:priority, :high | :low | :normal}}
          | {:timeout, :infinity | non_neg_integer}
        ]) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  @spec start_child(atom | pid | {atom, any} | {:via, atom, any}, atom, any) ::
          :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start_child(sup_pid, module, args) do
    DynamicSupervisor.start_child(sup_pid, {module, args})
  end

  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
