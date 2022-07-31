# frozen_string_literal: true

module TNCL
  class ProcessRunner
    extend Forwardable

    include TNCL::Console

    class Error < Func::Error; end

    class AlreadyRunningError < Error; end

    attr_reader :command, :stdin, :stdout, :stderr

    def_delegators :@process, :wait, :kill, :running?
    def_delegators :@stdin, :write
    def_delegator :@ready, :wait, :wait_ready

    def initialize(*command, parent: ::Async::Task.current)
      @command = command
      @parent = parent

      @ready = ::Async::Notification.new

      @pipes = Array.new(3) { ::Async::IO.pipe }.flatten.each{ _1.sync = true }
      @stdin_r, @stdin, @stdout, @stdout_w, @stderr, @stderr_w = @pipes
    end

    def spawn
      raise AlreadyRunning unless @process.nil?

      @ready.signal

      @process = ::Async::Process::Child.new(*@command, in: @stdin_r.io, out: @stdout_w.io, err: @stderr_w.io)

      @parent.async do
        @process.wait
        @pipes.each(&:close)
        log_info { "Process #{@command} is stopped" }
      end
    end

    def read(from: :stdout, timeout: nil)
      input = input_by_name(from)
      input.wait_readable(timeout)
      input.read(input.nread)
    end

    def query(payload, from: :stdout)
      write(payload)
      read(from:)
    end

    private

    def input_by_name(from)
      return @stdout if from == :stdout
      return @stderr if from == :stderr

      raise ArgumentError, "unknown input #{from}"
    end
  end
end