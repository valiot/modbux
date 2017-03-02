defmodule Modbus.Tcp do
  @moduledoc false
  alias Modbus.Request
  alias Modbus.Response

  def pack_req(cmd, transid) do
    cmd |> Request.pack |> wrap(transid)
  end

  def parse_req(wraped) do
    {pack, transid} = wraped |> unwrap
    {pack |> Request.parse, transid}
  end

  def pack_res(cmd, values, transid) do
    cmd |> Response.pack(values) |> wrap(transid)
  end

  def parse_res(cmd, wraped, transid) do
    Response.parse(cmd, wraped |> unwrap(transid))
  end

  def res_len(cmd) do
    Response.length(cmd) + 6;
  end

  def req_len(cmd) do
    Request.length(cmd) + 6;
  end

  def wrap(payload, transid) do
    size =  :erlang.byte_size(payload)
    <<transid::16, 0, 0, size::16, payload::binary>>
  end

  def unwrap(<<transid::16, 0, 0, size::16, payload::binary>>, transid) do
    ^size = :erlang.byte_size(payload)
    payload
  end

  def unwrap(<<transid::16, 0, 0, size::16, payload::binary>>) do
    ^size = :erlang.byte_size(payload)
    {payload, transid}
  end

end
