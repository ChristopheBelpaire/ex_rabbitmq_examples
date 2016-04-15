defmodule ReceiveLogs do
  def wait_for_messages(channel, name, messages) do
    receive do
      {:basic_deliver, payload, _meta} ->
        IO.puts " [x] Received #{payload}"
        wait_for_messages(channel, name, [ [name, payload] | messages])
      {:get_messages, sender} ->
        send(sender, {:messages, messages})
    end
  end
end
