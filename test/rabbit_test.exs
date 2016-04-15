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

  test "work queues" do
    {:ok, connection} = AMQP.Connection.open("amqp://default.docker")
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Basic.publish(channel, "", "task_queue", "Hello worker 1", persistent: true)
    AMQP.Basic.publish(channel, "", "task_queue", "Hello worker 2", persistent: true)
    AMQP.Basic.publish(channel, "", "task_queue", "Hello worker 3", persistent: true)
    AMQP.Basic.publish(channel, "", "task_queue", "Hello worker 4", persistent: true)

    AMQP.Queue.declare(channel, "task_queue", durable: true)
    AMQP.Basic.qos(channel, prefetch_count: 1)
  	worker1 = spawn(Worker, :wait_for_messages, [channel, "worker 1", []])
  	worker2 = spawn(Worker, :wait_for_messages, [channel, "worker 2", []])

  	AMQP.Basic.consume(channel, "task_queue", worker1)
  	AMQP.Basic.consume(channel, "task_queue", worker2)

    :timer.sleep(1000)

    send(worker1, {:get_messages,self})
  	receive do
  		{:messages, messages} ->
  			assert messages == [["worker 1", "Hello worker 3"], ["worker 1", "Hello worker 1"]]
  	end

  	send(worker2, {:get_messages,self})
  	receive do
  		{:messages, messages} ->
  			assert messages == [["worker 2", "Hello worker 4"], ["worker 2", "Hello worker 2"]]
  	end

  end

  test "publish/subscribe" do
    {:ok, connection} = AMQP.Connection.open("amqp://default.docker")
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Exchange.declare(channel, "logs", :fanout)

    {:ok, %{queue: queue_1_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    {:ok, %{queue: queue_2_name}} = AMQP.Queue.declare(channel, "", exclusive: true)

    AMQP.Queue.bind(channel, queue_1_name, "logs")
    AMQP.Queue.bind(channel, queue_2_name, "logs")

    AMQP.Basic.publish(channel, "logs", "", "Hello subscribers")


    subscriber1 = spawn(ReceiveLogs, :wait_for_messages, [channel, "subscriber 1", []])
    subscriber2 = spawn(ReceiveLogs, :wait_for_messages, [channel, "subscriber 2", []])


    AMQP.Basic.consume(channel, queue_1_name, subscriber1, no_ack: true)
    AMQP.Basic.consume(channel, queue_2_name, subscriber2, no_ack: true)


    send(subscriber1, {:get_messages,self})
    receive do
      {:messages, messages} ->
        assert messages == [["subscriber 1", "Hello subscribers"]]
    end

    send(subscriber2, {:get_messages,self})
    receive do
      {:messages, messages} ->
        assert messages == [["subscriber 2", "Hello subscribers"]]
    end
  end

end
