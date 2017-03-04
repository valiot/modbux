defmodule Modbus.Rtu do
  @moduledoc false
  alias Modbus.Helper
  alias Modbus.Request
  alias Modbus.Response

  def pack_req(cmd) do
    cmd |> Request.pack |> wrap
  end

  def parse_req(wraped) do
    wraped |> unwrap |> Request.parse
  end

  def pack_res(cmd, values) do
    cmd |> Response.pack(values) |> wrap
  end

  def parse_res(cmd, wraped) do
    Response.parse(cmd, wraped |> unwrap)
  end

  def res_len(cmd) do
    Response.length(cmd) + 2;
  end

  def req_len(cmd) do
    Request.length(cmd) + 2;
  end

  def wrap(payload) do
    <<crc_hi, crc_lo>> = Helper.crc(payload)
    <<payload::binary, crc_hi, crc_lo>>
  end

  def unwrap(data) do
    size = :erlang.byte_size(data)-2
    <<payload::binary-size(size), crc_hi, crc_lo>> = data
    <<^crc_hi, ^crc_lo>> = Helper.crc(payload)
    payload
  end

end
