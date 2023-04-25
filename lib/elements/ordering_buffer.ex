defmodule Basic.Elements.OrderingBuffer do
  use Membrane.Filter
  alias Basic.Formats.Packet

  # Tthis element is responsible for ordering the incoming packets,
  # based on their sequence id.

  def_input_pad(:input, demand_unit: :buffers, caps: {Packet, type: :custom_packets})

  def_output_pad(:output, caps: {Packet, type: :custom_packets})

  # Need to hold a list of ordered packets, as well as a
  # sequence id of the packet, which most recently was
  # sent through the output pad.
  # We need to know if there are some packets missing
  # between the last sent packet and the first packet
  # in our ordered list
  @impl true
  def handle_init(_options) do
    {:ok,
     %{
       ordered_packets: [],
       last_sent_seq_id: 0
     }
    }
  end

  # We simply send the :demand on the :input pad once
  # we receive a demand on the :output pad.
  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    { {:ok, demand: {Pad.ref(:input), size} }, state}
  end

  # The purpose of this callback is to process the
  # incoming buffer. It gets called once a new buffer
  # is available and waiting to be processed.
  @impl true
  def handle_process(:input, buffer, _context, state) do
    packet = unzip_packet(buffer.payload)
    ordered_packets = [packet | state.ordered_packets] |> Enum.sort()
    state = %{state | ordered_packets: ordered_packets}
    {last_seq_id, _} = Enum.at(ordered_packets, 0)

    if state.last_sent_seq_id + 1 == last_seq_id do
      {reversed_ready_packets_sequence, ordered_packets} = get_ready_packets_sequence(ordered_packets, [])
      [{last_sent_seq_id, _} | _] = reversed_ready_packets_sequence

      state = %{
        state
        | ordered_packets: ordered_packets,
          last_sent_seq_id: last_sent_seq_id
      }
      buffers = Enum.reverse(reversed_ready_packets_sequence) |> Enum.map(fn {_seq_id, data} -> data end)

      { {:ok, buffer: {:output, buffers} }, state}
    else
      { {:ok, redemand: :output}, state}
    end
  end

  # Packets look like:
  #
  #   seq:7][frameid:2][timestamp:3]data
  #
  defp unzip_packet(packet) do
    regex = ~r/^\[seq\:(?<seq_id>\d+)\](?<data>.*)$/
    %{"data" => data, "seq_id" => seq_id} = Regex.named_captures(regex, packet)
    {String.to_integer(seq_id), %Membrane.Buffer{payload: data} }
  end


  defp get_ready_packets_sequence([], acc) do
    {acc, []}
  end

  defp get_ready_packets_sequence(
    [{first_id, _first_data} = first_seq | [{second_id, second_data} | rest]], acc)
  when first_id + 1 == second_id do
    get_ready_packets_sequence([{second_id, second_data} | rest], [first_seq | acc])
  end

  defp get_ready_packets_sequence([first_seq | rest], acc) do
    {[first_seq | acc], rest}
  end
end
