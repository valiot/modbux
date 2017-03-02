defmodule Modbus.Model.Shared do
  alias Modbus.Model

  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  def stop(pid) do
    Agent.stop(pid)
  end

  def state(pid) do
    Agent.get(pid, fn model -> model end)
  end

  def apply(pid, cmd) do
    Agent.get_and_update(pid, fn model ->
      {model2, values} = Model.apply(model, cmd)
      {{:ok, values}, model2}
    end)
  end

  defp init(params) do
    Keyword.fetch!(params, :model)
  end
end
