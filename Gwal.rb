require 'thread'

module Gwal
  class ThreadPool
    def initialize(size)
      @queue = Queue.new
      @pool = Array.new(size) do
        Thread.new do
          loop do
            task = @queue.pop
            break if task.nil?

            task.call
          end
        end
      end
    end

    def schedule(&task)
      @queue << task
    end

    def shutdown
      @pool.size.times { @queue << nil }
      @pool.each(&:join)
    end
  end

  class Future
    def initialize(&block)
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @block = block
      @result = nil
      @resolved = false
      @thread = Thread.new do
        @mutex.synchronize do
          @result = @block.call
          @resolved = true
          @condition.signal
        end
      end
    end

    def value
      @mutex.synchronize do
        @condition.wait(@mutex) until @resolved
        @result
      end
    end
  end

  class Promise
    def initialize
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @resolved = false
      @result = nil
    end

    def fulfill(result)
      @mutex.synchronize do
        @result = result
        @resolved = true
        @condition.signal
      end
    end

    def future
      Future.new do
        @mutex.synchronize do
          @condition.wait(@mutex) until @resolved
          @result
        end
      end
    end
  end

  class SynchronizedQueue
    def initialize
      @queue = Queue.new
      @mutex = Mutex.new
      @condition = ConditionVariable.new
    end

    def push(item)
      @mutex.synchronize do
        @queue.push(item)
        @condition.signal
      end
    end

    def pop
      @mutex.synchronize do
        @condition.wait(@mutex) if @queue.empty?
        @queue.pop
      end
    end
  end

  class Monitor
    def initialize
      @mutex = Mutex.new
    end

    def synchronize(&block)
      @mutex.synchronize(&block)
    end
  end

  class Barrier
    def initialize(num_threads)
      @num_threads = num_threads
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @count = 0
    end

    def wait
      @mutex.synchronize do
        @count += 1
        if @count >= @num_threads
          @condition.broadcast
        else
          @condition.wait(@mutex)
        end
      end
    end
  end

  class Semaphore
    def initialize(initial_count)
      @count = initial_count
      @mutex = Mutex.new
      @condition = ConditionVariable.new
    end

    def acquire
      @mutex.synchronize do
        while @count <= 0
          @condition.wait(@mutex)
        end
        @count -= 1
      end
    end

    def release
      @mutex.synchronize do
        @count += 1
        @condition.signal
      end
    end
  end

  class MonitorObject
    def initialize
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @resource = nil
    end

    def set_resource(resource)
      @mutex.synchronize do
        @resource = resource
        @condition.signal
      end
    end

    def get_resource
      @mutex.synchronize do
        @condition.wait(@mutex) until @resource
        @resource
      end
    end
  end

  class DoubleCheckedLocking
    def initialize
      @mutex = Mutex.new
      @resource = nil
    end

    def get_resource
      return @resource if @resource

      @mutex.synchronize do
        unless @resource
          @resource = initialize_resource
        end
      end

      @resource
    end

    private

    def initialize_resource
      # Simulate resource initialization
      sleep(1)
      "Initialized Resource"
    end
  end

  class ReadWriteLock
    def initialize
      @mutex = Mutex.new
      @readers = 0
      @writers = 0
      @resource_mutex = Mutex.new
      @read_condition = ConditionVariable.new
      @write_condition = ConditionVariable.new
    end

    def acquire_read
      @mutex.synchronize do
        while @writers > 0
          @read_condition.wait(@mutex)
        end
        @readers += 1
      end
    end

    def release_read
      @mutex.synchronize do
        @readers -= 1
        if @readers.zero?
          @write_condition.signal
        end
      end
    end

    def acquire_write
      @mutex.synchronize do
        @writers += 1
        while @readers > 0
          @write_condition.wait(@mutex)
        end
      end
      @resource_mutex.lock
    end

    def release_write
      @resource_mutex.unlock
      @mutex.synchronize do
        @writers -= 1
        @read_condition.broadcast
        @write_condition.signal
      end
    end
  end

  class MonitorWithConditionVariables
    def initialize
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @resource = nil
    end

    def wait_for_resource
      @mutex.synchronize { @condition.wait(@mutex) until @resource }
    end

    def set_resource(resource)
      @mutex.synchronize do
        @resource = resource
        @condition.broadcast
      end
    end
  end

  class LeaderFollowers
    def initialize(worker_count)
      @queue = Queue.new
      @workers = Array.new(worker_count) do
        Thread.new do
          loop do
            task = @queue.pop
            break if task.nil?

            task.call
          end
        end
      end
      @leader = @workers.first
    end

    def schedule(&task)
      @queue << task
    end

    def shutdown
      @workers.size.times { @queue << nil }
      @workers.each(&:join)
    end
  end
end
