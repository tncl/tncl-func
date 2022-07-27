# frozen_string_literal: true

module TNCL
  module Func
    class Function # rubocop:disable Metrics/ClassLength
      attr_reader :name, :image

      include Console

      class Error < Func::Error; end

      class InitializationError < Error; end

      class InitializationTimeoutError < InitializationError; end
      class NotReadyError < InitializationError; end
      class ImageNotFoundError < InitializationError; end

      DOCKER_RUN_COMMAND = ["docker", "run", "-i", "--rm", "--pull", "never"].freeze
      READY = "READY"
      READY_TIMEOUT = 5

      def initialize(name:, image:, parent: Async::Task.current)
        @name = name
        @image = image
        @parent = parent

        @pipes = Array.new(3) { Async::IO.pipe }.flatten
        @stdin_r, @stdin_w, @stdout_r, @stdout_w, @stderr_r, @stderr_w = @pipes
      end

      def start
        ready_waiter = @parent.async { wait_ready }

        stderr_reader = @parent.async { read_stderr }

        @process = spawn_container
        fail_waiter = @parent.async { wait_fail }

        @parent.async do
          @process.wait
          stderr_reader.stop
          @pipes.each(&:close)
          logger.info(self) { "Function #{@name} is stopped" }
        end

        wait_init(ready_waiter, stderr_reader, fail_waiter)

        logger.info(self) { "Function #{@name} is ready" }
      end

      def call(payload)
        write(payload)
        read
      end

      def stop
        return unless @process.running?

        @process.kill

        logger.info(self) { "Function #{@name} is stopping" }
      end

      def wait = @process.wait

      private

      def read(input = @stdout_r, parse: true, timeout: nil)
        input.wait_readable(timeout)
        d = input.read(input.nread).strip
        return d unless parse

        Base64.decode64(d)
      end

      def write(payload) = @stdin_w.write("#{Base64.encode64(payload)}\n")

      def parse_docker_error!(line)
        return unless line.include?("No such image")

        raise ImageNotFoundError, "function '#{@name}' initialization failed: image '#{@image}' is not found"
      end

      def wait_first(*tasks)
        c = Async::Notification.new

        await = lambda do |task|
          @parent.async do
            task.wait
            c.signal(task)
          rescue StandardError
            c.signal(task)
          end
        end

        tasks.each(&await)

        c.wait.yield_self { [_1, tasks - [_1]] }
      end

      def wait_ready
        raise "ERROR" unless read(parse: false, timeout: READY_TIMEOUT) == READY
      rescue Async::TimeoutError
        raise InitializationTimeoutError, "function '#{@name}' initialization timed out" if @process.running?
      rescue Async::Stop
        nil
      end

      def read_stderr
        loop do
          output = read(@stderr_r, parse: false)
          lines = output.split("\n")
          lines.each do |line|
            next parse_docker_error!(line) if line.start_with?("docker")

            logger.info(self) { "Function output: #{line}" }
          end
        end
      rescue Async::Stop, Async::TimeoutError
        nil
      end

      def wait_fail
        @process.wait
        raise InitializationError, "process quited"
      rescue Async::Stop
        nil
      end

      def wait_init(*tasks)
        done, running = wait_first(*tasks)
        running.each(&:stop).each(&:wait)
        begin
          done.wait
        rescue StandardError => e
          stop
          logger.info(self) { "Function '#{@name}' failed to initialize: #{e}" }
          raise
        end
      end

      def spawn_container
        Async::Process::Child.new(*DOCKER_RUN_COMMAND, @image, in: @stdin_r.io,
                                                               out: @stdout_w.io,
                                                               err: @stderr_w.io)
      end
    end
  end
end
