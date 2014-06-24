require "logger"

module Bosh
  class ThreadPool
    def initialize(options = {})
      @actions = []
      @lock = Mutex.new
      @cv = ConditionVariable.new
      @max_threads = options[:max_threads] || 1
      @available_threads = @max_threads
      @logger = options[:logger]
      @boom = nil
      @original_thread = Thread.current
      @threads = []
      @state = :open
    end

    def wrap
      begin
        yield self
        wait
      ensure
        shutdown
      end
    end

    def pause
      @lock.synchronize do
        @logger.debug("#{Thread.current.object_id} Pausing in threadpool")
        @state = :paused
      end
    end

    def resume
      @lock.synchronize do
        @logger.debug("#{Thread.current.object_id} Resuming in threadpool")
        @state = :open
        [@available_threads, @actions.size].min.times do
          @available_threads -= 1
          create_thread
        end
      end
    end

    def process(&block)
      @lock.synchronize do
        @actions << block
        if @state == :open
          if @available_threads > 0
            @logger.debug("#{Thread.current.object_id} Creating new thread")
            @available_threads -= 1
            create_thread
          else
            @logger.debug("#{Thread.current.object_id} All threads are currently busy, queuing action")
          end
        elsif @state == :paused
          @logger.debug("#{Thread.current.object_id} Pool is paused, queueing action.")
        end
        @logger.debug("#{Thread.current.object_id} Releasing process lock")
      end
    end

    def create_thread
      thread = Thread.new do
        puts 'started thread'
        @logger.debug("#{Thread.current.object_id} Started thread in create_thread")

        begin
          loop do
            action = nil
            @logger.debug("#{Thread.current.object_id} Waiting to get the create_thread lock")

            @lock.synchronize do
              @logger.debug("#{Thread.current.object_id} Got create_thread lock")
              action = @actions.shift unless @boom
              if action
                @logger.debug("#{Thread.current.object_id} Found an action that needs to be processed")
              else
                @logger.debug("#{Thread.current.object_id} Thread is no longer needed, cleaning up")
                @available_threads += 1
                @threads.delete(thread) if @state == :open
              end
            end

            unless action
              @logger.debug("#{Thread.current.object_id} No actions, exiting")
              break
            end

            begin
              @logger.debug("#{Thread.current.object_id} Executing action in create_thread")
              action.call
            rescue Exception => e
              @logger.debug("#{Thread.current.object_id} puts got exception #{e.message}")
              raise_worker_exception(e)
            end
          end
        end
        @lock.synchronize do
          @logger.debug("sv signal checking")
          @cv.signal unless working?
        end
      end
      @threads << thread
    end

    def raise_worker_exception(exception)
      if exception.respond_to?(:backtrace)
        @logger.debug("#{Thread.current.object_id} Worker thread raised exception: #{exception} - #{exception.backtrace.join("\n")}")
      else
        @logger.debug("#{Thread.current.object_id} Worker thread raised exception: #{exception}")
      end
      @lock.synchronize do
        @logger.debug("#{Thread.current.object_id} lock in raising exception")
        @boom = exception if @boom.nil?
      end
    end

    def working?
      @logger.debug("#{Thread.current.object_id} Working? actions : #{@actions.inspect},
        available threads: #{@available_threads}, max threads: #{@max_threads}, boom: #{@boom.inspect}")

      @boom.nil? && (@available_threads != @max_threads || !@actions.empty?)
    end

    def wait
      @logger.debug("#{Thread.current.object_id} Waiting for tasks to complete")
      @lock.synchronize do
        @cv.wait(@lock) while working?
        raise @boom if @boom
      end
    end

    def shutdown
      return if @state == :closed
      @logger.debug("#{Thread.current.object_id} Shutting down pool")
      @lock.synchronize do
        return if @state == :closed
        @state = :closed
        @actions.clear
      end
      @threads.each { |t| t.join }
    end

  end

end
