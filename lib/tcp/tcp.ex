defmodule Modbux.Tcp do
  @moduledoc """
  Tcp message helper, functions that handles TCP responses/requests messages.
  """
  alias Modbux.Request
  alias Modbux.Response
  require Logger

  @spec pack_req(
          {:fc | :phr | :rc | :rhr | :ri | :rir, integer, integer, maybe_improper_list | integer},
          integer
        ) :: <<_::48, _::_*8>>
  def pack_req(cmd, transid) do
    cmd |> Request.pack() |> wrap(transid)
  end

  @spec parse_req(<<_::48, _::_*8>>) ::
          {{:einval | :error | :fc | :phr | :rc | :rhr | :ri | :rir, byte, char, [any] | char}, char}
  def parse_req(wraped) do
    {pack, transid} = wraped |> unwrap
    {pack |> Request.parse(), transid}
  end

  @spec pack_res(
          {:fc | :phr | :rc | :rhr | :ri | :rir, integer, any, maybe_improper_list | integer},
          any,
          integer
        ) :: <<_::48, _::_*8>>
  def pack_res(cmd, values, transid) do
    cmd |> Response.pack(values) |> wrap(transid)
  end

  @spec parse_res(any, <<_::48, _::_*8>>, char) :: nil | [any] | {:error, any} | {:error, byte, <<_::104>>}
  def parse_res(cmd, wraped, transid) do
    Response.parse(cmd, wraped |> unwrap(transid))
  end

  @spec res_len({:fc | :phr | :rc | :rhr | :ri | :rir, any, any, any}) :: number
  def res_len(cmd) do
    Response.length(cmd) + 6
  end

  @spec req_len({:fc | :phr | :rc | :rhr | :ri | :rir, any, any, any}) :: integer
  def req_len(cmd) do
    Request.length(cmd) + 6
  end

  @doc """
  Splits a tcp stream into complete Modbus TCP messages (ADUs), each one framed by the
  length field of its MBAP header. Returns the complete messages and the remaining bytes.
  """
  @spec split_adus(binary) :: {[binary], binary}
  def split_adus(data), do: split_adus(data, [])

  defp split_adus(<<transid::16, protocol_id::16, len::16, tail::binary>>, adus)
       when byte_size(tail) >= len do
    <<payload::binary-size(len), rest::binary>> = tail
    adu = <<transid::16, protocol_id::16, len::16, payload::binary>>
    split_adus(rest, [adu | adus])
  end

  defp split_adus(rest, adus), do: {Enum.reverse(adus), rest}

  @spec wrap(binary, integer) :: <<_::48, _::_*8>>
  def wrap(payload, transid) do
    size = :erlang.byte_size(payload)
    <<transid::16, 0, 0, size::16, payload::binary>>
  end

  @spec unwrap(<<_::48, _::_*8>>, char) :: nil | binary
  def unwrap(<<transid::16, protocol_id_h, protocol_id_l, size::16, payload::binary>> = msg, transid) do
    r_size = :erlang.byte_size(payload)

    check_protocol_identifier(protocol_id_h, protocol_id_l)

    data =
      if size == r_size do
        payload
      else
        Logger.error(
          "(#{__MODULE__}) size = #{size}, payload_size = #{r_size}, msg = #{inspect(msg, base: :hex)}"
        )

        nil
      end

    data
  end

  @spec unwrap(<<_::48, _::_*8>>) :: {binary(), char()}
  def unwrap(<<transid::16, protocol_id_h, protocol_id_l, size::16, payload::binary>>) do
    ^size = :erlang.byte_size(payload)
    check_protocol_identifier(protocol_id_h, protocol_id_l)
    {payload, transid}
  end

  def unwrap(inv_data) do
    Logger.error("(#{__MODULE__}) invalid data: #{inspect(inv_data, base: :hex)}")
    raise("(#{__MODULE__}) invalid data: #{inspect(inv_data)}")
  end

  # Protocol identifier ->	MODBUS protocol = 0x00, 0x00
  defp check_protocol_identifier(0, 0), do: :ok
  defp check_protocol_identifier(protocol_id_h, protocol_id_l),
    do: Logger.warning("(#{__MODULE__}) Protocol Identifier: #{inspect(<<protocol_id_h, protocol_id_l>>, base: :hex)}")
end
