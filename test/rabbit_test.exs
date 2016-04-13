defmodule RabbitTest do
  use ExUnit.Case
  doctest Rabbit

  test "hello world" do
    {:ok, connection} = AMQP.Connection.open("amqp://default.docker")
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, "hello")
    AMQP.Basic.publish(channel, "", "hello", "Hello World!")

    AMQP.Basic.consume(channel,
                   "hello",
                   nil, # consumer process, defaults to self()
                   no_ack: true)
    receive do
      {:basic_deliver, payload, _meta} ->
        assert payload == "Hello World!"
    end
  end
end
