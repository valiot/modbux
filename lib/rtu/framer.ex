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
              slave_id: nil,
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
  # I could put the CRC & packet size compilation here, but seems like a lot
  # and an implementation detail that ought be handled upstream with my other
  # Modbus function
  def add_framing(data, state) do
    {:ok, data, state}
  end

  def remove_framing(data, state) do
    new_state = process_data(data, state.expected_length, state.in_process, state)
    rc = if buffer_empty?(new_state), do: :ok, else: :in_frame

    if has_error?(new_state),
      do: dispatch({:ok, new_state.error_message, new_state}),
      else: dispatch({rc, new_state.lines, new_state})
  end

  def frame_timeout(state) do
    partial_line = {:partial, state.processed <> state.in_process}
    new_state = %{state | processed: <<>>, in_process: <<>>}
    {:ok, [partial_line], new_state}
  end

  def flush(direction, state) when direction == :receive or direction == :both do
    %State{max_len: state.max_len, slave_id: state.slave_id, behavior: state.behavior}
  end

  def flush(_direction, state) do
    state
  end

  # handle empty byte
  defp process_data(<<>>, nil, _in_process, state) do
    # just move along...
    state
  end

  # get first byte (index 0)
  defp process_data(<<slave_id::size(8), b_tail::binary>>, nil, _in_process, %{index: 0} = state) do
    Logger.debug("line 0")
    new_state = %{state | slave_id: slave_id, index: 1, in_process: <<slave_id>>}

    if byte_size(b_tail) > 0,
      do: process_data(b_tail, nil, <<slave_id>>, new_state),
      else: new_state
  end

  # get second byte (function code) (index 1)
  defp process_data(<<fc::size(8), b_tail::binary>>, nil, in_process, %{index: 1} = state) do
    Logger.debug("line 1")

    new_state = %{state | fc: fc, index: 2, in_process: in_process <> <<fc>>}

    if byte_size(b_tail) > 0,
      do: process_data(b_tail, nil, <<state.slave_id, fc>>, new_state),
      else: new_state
  end

  # Clause for functions code => 5, 6
  defp process_data(<<len::size(8), b_tail::binary>>, nil, _in_process, %{index: 2, fc: fc} = state)
       when fc in [5, 6] do
    Logger.debug("fc 5 or 6")

    new_state =
      if state.behavior == :slave do
        %{state | expected_length: 8, index: 3, in_process: state.in_process <> <<len>>}
      else
        %{state | expected_length: 8, index: 3, in_process: state.in_process <> <<len>>}
      end

    process_data(b_tail, new_state.expected_length, <<state.slave_id, new_state.fc, len>>, new_state)
  end

  # Clause for functions code => 15 and 16
  defp process_data(<<len::size(8), b_tail::binary>>, nil, _in_process, %{index: 2, fc: fc} = state)
       when fc in [15, 16] do
    Logger.debug("fc 15 or 16")

    new_state =
      if state.behavior == :slave do
        %{state | expected_length: 7, index: 3, in_process: state.in_process <> <<len>>}
      else
        %{state | expected_length: 8, index: 3, in_process: state.in_process <> <<len>>}
      end

    process_data(b_tail, new_state.expected_length, <<state.slave_id, new_state.fc, len>>, new_state)
  end

  defp process_data(<<len::size(8), b_tail::binary>>, _len, in_process, %{index: 6, fc: fc} = state)
       when fc in [15, 16] do
    Logger.debug("fc 15 or 16, len")

    new_state =
      if state.behavior == :slave do
        %{state | expected_length: len + 9, index: 7, in_process: state.in_process <> <<len>>}
      else
        %{state | expected_length: 8, index: 7, in_process: state.in_process <> <<len>>}
      end

    process_data(b_tail, new_state.expected_length, in_process <> <<len>>, new_state)
  end

  # Clause for functions code => 1, 2, 3 and 4
  defp process_data(<<len::size(8), b_tail::binary>>, nil, _in_process, %{index: 2, fc: fc} = state)
       when fc in [1, 2, 3, 4] do
    Logger.debug("fc 1, 2, 3 or 4")

    new_state =
      if state.behavior == :slave do
        %{state | expected_length: 8, index: 3, in_process: state.in_process <> <<len>>}
      else
        %{state | expected_length: len + 5, index: 3, in_process: state.in_process <> <<len>>}
      end

    process_data(b_tail, new_state.expected_length, <<state.slave_id, new_state.fc, len>>, new_state)
  end

  # add a catch all fc (report 18)

  # # write multiple registers (function code 16)
  # defp process_data(b_tail, nil, _in_process, %{index: 2, fc: 16} = state) do
  #   new_state = %{state | expected_length: 8, index: 3, in_process: state.in_process <> <<state.slave_id, state.fc>>}
  #   process_data(b_tail, 8, <<state.slave_id, new_state.fc>>, new_state)
  # end

  # # read multiple registers error (function code 131)
  # defp process_data(b_tail, nil, _in_process, %{index: 2, fc: 131} = state) do
  #   new_state = %{state | expected_length: 5, error: true, error_message: :modbus_exception, index: 3, in_process: state.in_process <> <<state.slave_id, state.fc>>}
  #   process_data(b_tail, 5, <<state.slave_id, new_state.fc>>, new_state)
  # end

  # # write multiple registers error (function code 144)
  # defp process_data(b_tail, nil, _in_process, %{index: 2, fc: 144} = state) do
  #   new_state = %{state | expected_length: 5, error: true, error_message: :modbus_exception, index: 3, in_process: state.in_process <> <<state.slave_id, state.fc>>}
  #   process_data(b_tail, 5, <<state.slave_id, new_state.fc>>, new_state)
  # end

  # # deal with data that's too long
  # defp process_data(data, expected_length, in_process, state)
  #      when byte_size(in_process <> data) > expected_length do
  #   Logger.info(
  #     "(#{__MODULE__}) fun1 #{inspect(state)}, data: #{inspect(data)}, incoming: #{inspect(in_process)}"
  #   )

  #   combined_data = in_process <> data
  #   # {relevant_data, tail} = String.split_at(combined_data, expected_length)
  #   # +5 for the 5 control bytes
  #   relevant_data = Kernel.binary_part(combined_data, 0, expected_length)
  #   new_lines = state.lines ++ [relevant_data]
  #   # check_crc(%{state | in_process: <<>>, processed: <<>>, index: 0, lines: new_lines})
  #   %{state | in_process: <<>>, processed: <<>>, index: 0, lines: new_lines}
  # end

  defp process_data(data, len, in_process, state) do
    data_len = byte_size(in_process <> data)

    {lines, state_in_process, line_idx} =
      if len == data_len do
        # we got the whole thing in 1 pass, so we're done
        {state.lines ++ [in_process <> data], <<>>, 0}
      else
        # need to keep reading
        {[], in_process <> data, data_len}
      end

    new_state = %{
      state
      | expected_length: len,
        lines: lines,
        in_process: state_in_process,
        index: line_idx,
        processed: <<>>
    }

    Logger.info(
      "(#{__MODULE__}) data_len: #{inspect(data_len)}, len: #{inspect(len)}, state: #{inspect(new_state)}"
    )

    # if this is the end of the packet, check it's CRC, else continue
    if line_idx == 0, do: check_crc(new_state), else: new_state
  end

  # helper functions

  defp buffer_empty?(state) do
    state.processed == <<>> and state.in_process == <<>>
  end

  defp has_error?(state) do
    state.error != nil
  end

  defp dispatch({:in_frame, _lines, _state} = msg), do: msg

  defp dispatch({rc, msg, state}) do
    {rc, msg, %State{max_len: state.max_len, slave_id: state.slave_id, behavior: state.behavior}}
  end

  # once we have the full packet, verify it's CRC16
  defp check_crc(state) do
    packet = state.lines |> List.first()
    packet_without_crc = Kernel.binary_part(packet, 0, byte_size(packet) - 2)
    expected_crc = Kernel.binary_part(packet, byte_size(packet), -2)
    <<hi_crc, lo_crc>> = Helper.crc(packet_without_crc)
    real_crc = <<lo_crc, hi_crc>>
    Logger.info("(#{__MODULE__}) #{inspect(expected_crc)} == #{inspect(real_crc)}")

    if real_crc == expected_crc,
      do: state,
      else: %{state | error: true, error_message: [{:error, :echksum, "CRC Error"}]}
  end
end
