# frozen_string_literal: true

module TNCL
  module Func
    class Function
      extend Forwardable

      attr_reader :name, :image

      include TNCL::Console

      class Error < Func::Error; end

      class InitializationError < Error; end

      class InitializationTimeoutError < InitializationError; end
      class NotReadyError < InitializationError; end
      class ImageNotFoundError < InitializationError; end
      class WrongReadyMessageError < InitializationError; end

      DOCKER_RUN_COMMAND = ["docker", "run", "-i", "--rm", "--pull", "never"].freeze
      READY = "READY"
      READY_TIMEOUT = 5

      def_delegator :@process, :wait

      def initialize(name:, image:, parent: ::Async::Task.current)
        @name = name
        @image = image
        @parent = parent
      end

      def start
        @process = Docker::Runner.new(@image)

        ready_waiter  = @parent.async { wait_ready }
        stderr_reader = @parent.async { read_stderr }
        fail_waiter   = @parent.async { wait_fail }

        @process.spawn

        wait_init(ready_waiter, stderr_reader, fail_waiter, stop_except: stderr_reader)

        log_info { "Function #{@name} is ready" }
      end

      def call(payload)
        @process.query("#{Base64.encode64(payload)}\n")
      end

      def stop
        return unless @process.running?

        @process.kill

        log_info { "Function #{@name} is stopping" }
      end

      private

      def read(from: :stdout, timeout: nil)
        @process.read(from:, timeout:).strip.then do |d|
          from == :stdout ? Base64.decode64(d) : d
        end
      end

      def parse_docker_error!(line)
        return unless line.include?("No such image")

        raise ImageNotFoundError, "function '#{@name}': image '#{@image}' is not found"
      end

      def wait_ready
        @process.wait_ready
        m = read(timeout: READY_TIMEOUT)
        return if m == READY

        raise WrongReadyMessageError,
              "function '#{@name}': wrong ready message. Expected: '#{READY}', received: '#{m[0..80]}'"
      rescue ::Async::TimeoutError
        raise InitializationTimeoutError, "function '#{@name}' initialization timed out" if @process.running?
      rescue ::Async::Stop
        nil
      end

      def read_stderr
        @process.wait_ready
        loop do
          output = read(from: :stderr)
          lines = output.split("\n")
          lines.each do |line|
            next parse_docker_error!(line) if line.start_with?("docker")

            log_info { "Function output: #{line}" }
          end
        end
      rescue ::Async::Stop, ::Async::TimeoutError
        nil
      end

      def wait_fail
        @process.wait_ready
        @process.wait
        raise InitializationError, "process quited"
      rescue ::Async::Stop
        nil
      end

      def wait_init(*tasks, stop_except: [])
        stop_except = [stop_except].flatten

        done, pending = TNCL::Async.wait_first(*tasks, parent: @parent)
        (pending - stop_except).each(&:stop).each(&:wait)
        begin
          done.wait
        rescue StandardError => e
          stop
          log_info { "Function '#{@name}' failed to initialize: #{e}" }
          raise
        end
      end
    end
  end
end
