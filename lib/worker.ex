defmodule Worker do
  def wait_for_messages(channel, name, messages) do
    receive do
      {:basic_deliver, payload, meta} ->
        IO.puts " [x] Received #{payload} in #{name}"

        IO.puts " [x] Done."
        AMQP.Basic.ack(channel, meta.delivery_tag)
        wait_for_messages(channel, name, [ [name, payload] | messages])

      {:get_messages, sender} ->
        send(sender, {:messages, messages})
    end
  end
end
