defmodule Modbus.Rtu.Framer do
  @behaviour Circuits.UART.Framing

  require Logger
  alias Modbus.Helper

  @moduledoc """
    Modbus docs here!
  """

  defmodule State do
    @moduledoc false
    defstruct behavior: nil,
              max_len: nil,
              expected_length: nil,
              index: 0,
              processed: <<>>,
              in_process: <<>>,
              fc: nil,
              error: nil,
              error_message: nil,
              lines: []
  end

  def init(args) do
    # modbus standard max len
    max_len = Keyword.get(args, :max_len, 255)
    behavior = Keyword.get(args, :behavior, :slave)
    state = %State{max_len: max_len, behavior: behavior}
    {:ok, state}
  end

  # do nothing, we assume this is already in the right form
  def add_framing(data, state) do
    {:ok, data, state}
  end

  def remove_framing(data, state) do
    # Logger.debug("new data #{inspect(state)}")
    new_state = process_data(state.in_process <> data, state.expected_length, state.processed, state)
    rc = if buffer_empty?(new_state), do: :ok, else: :in_frame
    # Logger.debug("new data processed #{inspect(new_state)}, #{inspect(rc)}")

    if has_error?(new_state),
      do: dispatch({:ok, new_state.error_message, new_state}),
      else: dispatch({rc, new_state.lines, new_state})
  end

  def frame_timeout(state) do
    partial_line = {:partial, state.processed <> state.in_process}
    new_state = %State{max_len: state.max_len, behavior: state.behavior}
    {:ok, [partial_line], new_state}
  end

  def flush(direction, state) when direction == :receive or direction == :both do
    %State{max_len: state.max_len, behavior: state.behavior}
  end

  def flush(_direction, state) do
    state
  end

  # helper functions

  # handle empty byte
  defp process_data(<<>>, _len, _in_process, state) do
    # Logger.debug("End #{inspect(state)}")
    state
  end

  # get first byte (index 0)
  defp process_data(<<slave_id::size(8), b_tail::binary>>, nil, processed, %{index: 0} = state) do
    # Logger.debug("line 0")
    new_state = %{state | index: 1, processed: processed <> <<slave_id>>, in_process: <<>>}
    process_data(b_tail, nil, new_state.processed, new_state)
  end

  # get second byte (function code) (index 1)
  defp process_data(<<fc::size(8), b_tail::binary>>, nil, processed, %{index: 1} = state) do
    # Logger.debug("line 1")
    new_state = %{state | fc: fc, index: 2, processed: processed <> <<fc>>}
    process_data(b_tail, nil, new_state.processed, new_state)
  end

  # Clause for functions code => 5, 6
  defp process_data(<<len::size(8), b_tail::binary>>, nil, processed, %{index: 2, fc: fc} = state)
       when fc in [5, 6] do
    # Logger.debug("fc 5 or 6")
    new_state = %{state | expected_length: 8, index: 3, processed: processed <> <<len>>}
    process_data(b_tail, new_state.expected_length, new_state.processed, new_state)
  end

  # Clause for functions code => 15 and 16
  defp process_data(<<len::size(8), b_tail::binary>>, nil, processed, %{index: 2, fc: fc} = state)
       when fc in [15, 16] do
    # Logger.debug("fc 15 or 16")
    new_state =
      if state.behavior == :slave do
        %{state | expected_length: 7, index: 3, processed: processed <> <<len>>}
      else
        %{state | expected_length: 8, index: 3, processed: processed <> <<len>>}
      end

    process_data(b_tail, new_state.expected_length, new_state.processed, new_state)
  end

  defp process_data(<<len::size(8), b_tail::binary>>, _len, processed, %{index: 6, fc: fc} = state)
       when fc in [15, 16] do
    # Logger.debug("fc 15 or 16, len")

    new_state =
      if state.behavior == :slave do
        %{state | expected_length: len + 9, index: 7, processed: processed <> <<len>>}
      else
        %{state | expected_length: 8, index: 7, processed: processed <> <<len>>}
      end

    process_data(b_tail, new_state.expected_length, new_state.processed, new_state)
  end

  # Clause for functions code => 1, 2, 3 and 4
  defp process_data(<<len::size(8), b_tail::binary>>, nil, processed, %{index: 2, fc: fc} = state)
       when fc in 1..4 do
    # Logger.debug("fc 1, 2, 3 or 4")

    new_state =
      if state.behavior == :slave do
        %{state | expected_length: 8, index: 3, processed: processed <> <<len>>}
      else
        %{state | expected_length: len + 5, index: 3, processed: processed <> <<len>>}
      end

    process_data(b_tail, new_state.expected_length, new_state.processed, new_state)
  end

  # Clause for exceptions.
  defp process_data(<<len::size(8), b_tail::binary>>, nil, processed, %{index: 2, fc: fc} = state)
       when fc in 129..144 do
    # Logger.debug("exceptions")

    new_state = %{state | expected_length: 5, index: 3, processed: processed <> <<len>>}

    process_data(b_tail, new_state.expected_length, new_state.processed, new_state)
  end

  # Catch all fc (error)
  defp process_data(_data, nil, processed, %{index: 2, fc: _fc} = state) do
    %{state | error: true, error_message: [{:error, :einval, processed}]}
  end

  defp process_data(<<data::size(8), b_tail::binary>>, len, processed, state) when is_binary(processed) do
    current_data = processed <> <<data>>

    # Logger.info(
    #   "(#{__MODULE__}) data_len: #{byte_size(current_data)}, len: #{inspect(len)}, state: #{inspect(state)}"
    # )

    if len == byte_size(current_data) do
      new_state = %{
        state
        | expected_length: nil,
          lines: [current_data],
          in_process: b_tail,
          index: 0,
          processed: <<>>
      }

      # we got the whole thing in 1 pass, so we're done
      check_crc(new_state)
    else
      new_state = %{state | index: state.index + 1, processed: current_data}
      # need to keep reading
      process_data(b_tail, len, current_data, new_state)
    end
  end

  def buffer_empty?(state) do
    state.processed == <<>> and state.in_process == <<>>
  end

  defp has_error?(state) do
    state.error != nil
  end

  defp dispatch({:in_frame, _lines, _state} = msg), do: msg

  defp dispatch({rc, msg, state}) do
    {rc, msg, %State{max_len: state.max_len, behavior: state.behavior}}
  end

  # once we have the full packet, verify it's CRC16
  defp check_crc(state) do
    [packet] = state.lines
    packet_without_crc = Kernel.binary_part(packet, 0, byte_size(packet) - 2)
    expected_crc = Kernel.binary_part(packet, byte_size(packet), -2)
    <<hi_crc, lo_crc>> = Helper.crc(packet_without_crc)
    real_crc = <<lo_crc, hi_crc>>
    # Logger.info("(#{__MODULE__}) #{inspect(expected_crc)} == #{inspect(real_crc)}")

    if real_crc == expected_crc,
      do: state,
      else: %{state | error: true, error_message: [{:error, :echksum, "CRC Error"}]}
  end
end
