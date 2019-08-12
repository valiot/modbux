defmodule Modbux.Rtu do
  @moduledoc """
  RTU message helper, functions that handles RTU responses/requests messages.
  """
  alias Modbux.Helper
  alias Modbux.Request
  alias Modbux.Response

  @spec pack_req({:fc | :phr | :rc | :rhr | :ri | :rir, integer, integer, maybe_improper_list | integer}) ::
          <<_::16, _::_*8>>
  def pack_req(cmd) do
    cmd |> Request.pack() |> wrap
  end

  @spec parse_req(<<_::16, _::_*8>>) ::
          {:einval | :error | :fc | :phr | :rc | :rhr | :ri | :rir, byte, char, [any] | char}
  def parse_req(wraped) do
    wraped |> unwrap |> Request.parse()
  end

  # invalid function
  @spec pack_res(
          <<_::16, _::_*8>>
          | {:fc | :phr | :rc | :rhr | :ri | :rir, integer, any, maybe_improper_list | integer},
          any
        ) :: <<_::16, _::_*8>>
  def pack_res(<<slave_id, fc, _btail::binary>>, :einval) do
    <<slave_id, fc + 0x80, 01>> |> wrap
  end

  # invalid address
  def pack_res(<<slave_id, fc, _btail::binary>>, :eaddr) do
    <<slave_id, fc + 0x80, 02>> |> wrap
  end

  def pack_res(cmd, values) do
    cmd |> Response.pack(values) |> wrap
  end

  @spec parse_res(any, <<_::16, _::_*8>>) :: nil | [any] | {:error, any} | {:error, byte, <<_::104>>}
  def parse_res(cmd, wraped) do
    Response.parse(cmd, wraped |> unwrap)
  end

  # exceptions
  @spec pack_res({any, integer, integer, integer}) :: <<_::16, _::_*8>>
  def pack_res({_reason, slave_id, fc, error_code}) do
    <<slave_id, fc, error_code>> |> wrap
  end

  @spec res_len({:fc | :phr | :rc | :rhr | :ri | :rir, any, any, any}) :: number
  def res_len(cmd) do
    Response.length(cmd) + 2
  end

  @spec req_len({:fc | :phr | :rc | :rhr | :ri | :rir, any, any, any}) :: integer
  def req_len(cmd) do
    Request.length(cmd) + 2
  end

  # CRC is little endian
  # http://modbus.org/docs/Modbux_over_serial_line_V1_02.pdf page 13
  @spec wrap(binary) :: <<_::16, _::_*8>>
  def wrap(payload) do
    <<crc_hi, crc_lo>> = Helper.crc(payload)
    <<payload::binary, crc_lo, crc_hi>>
  end

  # CRC is little endian
  # http://modbus.org/docs/Modbux_over_serial_line_V1_02.pdf page 13
  @spec unwrap(<<_::16, _::_*8>>) :: binary
  def unwrap(data) do
    size = :erlang.byte_size(data) - 2
    <<payload::binary-size(size), crc_lo, crc_hi>> = data
    <<^crc_hi, ^crc_lo>> = Helper.crc(payload)
    payload
  end
end
