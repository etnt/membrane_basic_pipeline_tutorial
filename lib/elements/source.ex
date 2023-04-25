defmodule Basic.Elements.Source do
  use Membrane.Source

  alias Membrane.Buffer
  alias Basic.Formats.Packet

  # The macro, def_options, allows us to define the parameters
  # which are expected to be passed while instantiating the element.
  def_options location: [type: :string, description: "Path to the file"]

  # The macro, def_output_pad, lets us define the output pad.
  # The second argument of the macro describes the :caps -
  # which is the type of data sent through the pad.
  #
  #  pads - input or output of an elements or a bin.
  #         output pads of one element are connected to
  #         input pads of another element or bin.
  #
  #  caps - capabilities, they define pads specification.
  #
  # We have also specified that the :output pad will work in the :pull mode.
  def_output_pad :output, [caps: {Packet, type: :custom_packets}, mode: :pull]

  # All we need to do here is to initialize the state.
  # location - holds a path to the input file.
  # content  - will be holding packets read from the file,
  @impl true
  def handle_init(options) do
    {:ok,
     %{
       location: options.location,
       content: nil
     }
    }
  end

  # There are three playback states: stopped, prepared, and playing.
  # The transition between the states can happen automatically or
  # as a result of a user's explicit action.

  # Read the file and split the content into lines.
  #@impl true
  def handle_stopped_to_prepared(_ctx, state) do
    content =
      state.location
      |> File.read!()
      |> String.split("\n")

    state = %{state | content: content}

    # We are returning the :caps action. That means that we want
    # to transmit the information about the supported caps through
    # the output pad, to the next element in the pipeline.
    { {:ok, [caps: {:output, %Packet{type: :custom_packets} }]}, state}
  end

  # Defines the behavior of the Source element while we are stopping
  # the pipeline. What we want to do is to clear the content buffer
  # in the state of our element.
  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    state = %{state | content: nil}
    {:ok, state}
  end

  # the :output pad is working in the pulling mode, hence succeeding
  # element have to ask the Source element for the data to be sent
  # and our element has to take care of keeping that data in some
  # kind of buffer until it is requested.
  # When the succeeding element requests data, the handle_demand/4
  # callback will be invoked.
  @impl true
  def handle_demand(:output, _size, :buffers, _ctx, state) do
    if state.content == [] do
      { {:ok, end_of_stream: :output}, state}
    else
      [first_packet | rest] = state.content
      state = %{state | content: rest}

      # we make use of the buffer: action, and specify that we want
      # to transmit the %Buffer structure through the :output pad.
      action = [buffer: {:output, %Buffer{payload: first_packet} }]

      # the :redemand action, take place on the :output pad.
      # This action will simply invoke the handle_demand/4 callback
      # once again, if the whole demand cannot be completely fulfilled
      # with the single handle_demand invocation we are just processing.
      action = action ++ [redemand: :output]
      { {:ok, action}, state}
    end
  end

end
