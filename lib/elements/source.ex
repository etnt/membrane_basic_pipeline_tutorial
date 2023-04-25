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
  # We have alsoe specified that the :output pad will work in the :pull mode.
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

end
