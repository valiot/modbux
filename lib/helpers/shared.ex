defmodule Modbux.Model.Shared do
  @moduledoc """
  An agent that holds the current state of the Server/Slave DB.
  """
  alias Modbux.Model

  @spec start_link(any, [
          {:debug, [any]}
          | {:hibernate_after, :infinity | non_neg_integer}
          | {:name, atom | {any, any} | {any, any, any}}
          | {:spawn_opt, :link | :monitor | {any, any}}
          | {:timeout, :infinity | non_neg_integer}
        ]) :: {:error, any} | {:ok, pid}
  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  @spec stop(atom | pid | {atom, any} | {:via, atom, any}) :: :ok
  def stop(pid) do
    Agent.stop(pid)
  end

  @spec state(atom | pid | {atom, any} | {:via, atom, any}) :: any
  def state(pid) do
    Agent.get(pid, fn model -> model end)
  end

  @spec apply(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def apply(pid, cmd) do
    Agent.get_and_update(pid, fn model -> Model.apply(model, cmd) end)
  end

  defp init(params) do
    Keyword.fetch!(params, :model)
  end
end
