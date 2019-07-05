defmodule Modbus.Rtu.Framer do
  @behaviour Circuits.UART.Framing

  alias Modbus.Crc16

  @moduledoc """
    Modbus docs here!
  """

  defmodule State do
    @moduledoc false
    defstruct [
      max_length: nil,
      expected_length: nil,
      line_index: 0,
      processed: <<>>,
      in_process: <<>>,
      function_code: nil, # modbus function
      slave_id: nil,
      error: nil,
      error_message: nil,
      lines: []
    ]
  end

  def init(args) do
    max_length = Keyword.get(args, :max_length, 255) # modbus standard max length
    slave_id = Keyword.get(args, :slave_id, 1) # modbus slave ID

    state = %State{max_length: max_length, slave_id: slave_id}
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
    #new_state = process_data(data, state.expected_length, state.in_process, state)
    new_state = process_data_improved(data, state.expected_length, state.in_process, state)
    rc = if buffer_empty?(new_state), do: :ok, else: :in_frame
    if has_error?(new_state), do: {:error, new_state.error_message, new_state}, else: {rc, new_state.lines, new_state}
  end

  def frame_timeout(state) do
    partial_line = {:partial, state.processed <> state.in_process}
    new_state = %{state | processed: <<>>, in_process: <<>>}
    {:ok, [partial_line], new_state}
  end

  def flush(direction, state) when direction == :receive or direction == :both do
    new_state = %{state | processed: <<>>, in_process: <<>>, lines: [], expected_length: nil}
    new_state
  end
  def flush(_direction, state) do
    state
  end

  def buffer_empty?(state) do
    state.processed == <<>> and state.in_process == <<>>
  end

  def has_error?(state) do
    state.error != nil
  end

  # handle empty byte
  defp process_data_improved(<<>>, nil, _in_process, state) do
    state # just move along...
  end

  # get first byte (line_index 0)
  defp process_data_improved(<<slave_id::size(8), other_data::binary>>, nil, _in_process, %{line_index: 0} = state) do
    # @TODO: raise error if slave_id != state.slave_id
    new_state = %{state | slave_id: slave_id, line_index: 1, in_process: <<slave_id>>}
    if byte_size(other_data) > 0, do: process_data_improved(other_data, nil, <<slave_id>>, new_state), else: new_state
  end

  # get second byte (function code) (linx_index 1)
  defp process_data_improved(<<function_code::size(8), other_data::binary>>, nil, in_process, %{line_index: 1} = state) do
    new_state = %{state | function_code: function_code, line_index: 2, in_process: in_process <> <<function_code>>}
    if byte_size(other_data) > 0, do: process_data_improved(other_data, nil,  <<state.slave_id, function_code>>, new_state), else: new_state
  end

  # read multiple registers (function code 3)
  defp process_data_improved(<<length::size(8), other_data::binary>>, nil, _in_process, %{line_index: 2, function_code: 3} = state) do
    new_state = %{state | expected_length: (length+5), line_index: 3, in_process: state.in_process <> <<length>>}
    process_data_improved(other_data, new_state.expected_length, <<state.slave_id, new_state.function_code, length>>, new_state)
  end

  # write multiple registers (function code 16)
  defp process_data_improved(other_data, nil, _in_process, %{line_index: 2, function_code: 16} = state) do
    new_state = %{state | expected_length: 8, line_index: 3, in_process: state.in_process <> <<state.slave_id, state.function_code>>}
    process_data_improved(other_data, 8, <<state.slave_id, new_state.function_code>>, new_state)
  end

  # read multiple registers error (function code 131)
  defp process_data_improved(other_data, nil, _in_process, %{line_index: 2, function_code: 131} = state) do
    new_state = %{state | expected_length: 5, error: true, error_message: :modbus_exception, line_index: 3, in_process: state.in_process <> <<state.slave_id, state.function_code>>}
    process_data_improved(other_data, 5, <<state.slave_id, new_state.function_code>>, new_state)
  end

  # write multiple registers error (function code 144)
  defp process_data_improved(other_data, nil, _in_process, %{line_index: 2, function_code: 144} = state) do
    new_state = %{state | expected_length: 5, error: true, error_message: :modbus_exception, line_index: 3, in_process: state.in_process <> <<state.slave_id, state.function_code>>}
    process_data_improved(other_data, 5, <<state.slave_id, new_state.function_code>>, new_state)
  end

  # deal with data that's too long
  defp process_data_improved(data, expected_length, in_process, state) when (byte_size(in_process <> data) > expected_length) do
    combined_data = in_process <> data
    relevant_data = Kernel.binary_part(combined_data, 0, expected_length) # +5 for the 5 control bytes
    new_lines = state.lines ++ [relevant_data]
    %{state | in_process: <<>>, processed: <<>>, line_index: 0, lines: new_lines}
  end

  defp process_data_improved(data, length, in_process, state)  do

    data_length = byte_size(in_process <> data)

    {lines, state_in_process, line_idx} = case (length == data_length) do
      true -> {state.lines++[in_process<>data], <<>>, 0} # we got the whole thing in 1 pass, so we're done
      _ -> {[], in_process<>data, data_length-1} # need to keep reading
    end

    new_state = %{state | expected_length: length, lines: lines, in_process: state_in_process, line_index: line_idx, processed: <<>>}

    # if this is the end of the packet, check it's CRC, else continue
    if line_idx == 0, do: check_crc(new_state), else: new_state
  end

  # once we have the full packet, verify it's CRC16
  defp check_crc(state) do
    packet = state.lines |> List.first
    packet_without_crc = Kernel.binary_part(packet, 0, byte_size(packet)-2)
    packet_crc = Kernel.binary_part(packet, byte_size(packet), -2)
    calculated_crc = <<Crc16.crc_16(packet_without_crc)::size(16)-little>>
    if calculated_crc == packet_crc, do: state, else: %{state | error: true, error_message: :invalid_crc}
  end



end
