# frozen_string_literal: true

class TNCL::Func::Function # rubocop:disable Metrics/ClassLength
  extend Forwardable

  attr_reader :name, :image

  include TNCL::Console

  class Error < TNCL::Func::Error; end

  class InitializationError < Error; end

  class InitializationTimeoutError < InitializationError; end
  class NotReadyError < InitializationError; end
  class ImageNotFoundError < InitializationError; end
  class WrongReadyMessageError < InitializationError; end

  class ExecutionError < Error; end

  class NotRunningError < ExecutionError; end
  class ExecutionTimeoutError < ExecutionError; end

  def_delegator :@process, :wait

  extend TNCL::Machine::Machine

  add_state_machine do # rubocop:disable Metrics/BlockLength
    state :created
    state :ready
    state :failed, final: true
    state :stopped, final: true
    state :executing
    state :idle

    group :terminated, :stopped, :failed
    group :ready_for_execution, :ready, :idle

    transition from: [:created, :executing], to: :failed
    transition from: :created, to: :ready
    transition from: :ready, to: [:stopped, :idle]
    transition from: :idle, to: [:stopped, :executing]
    transition from: :executing, to: :idle

    to_enter :ready, on_fail: :failed do
      ready_waiter = @parent.async { wait_ready }
      stderr_reader = @parent.async { read_stderr }
      fail_waiter = @parent.async { wait_fail }

      @process.spawn
      wait_init(ready_waiter, stderr_reader, fail_waiter, stop_except: stderr_reader)
      log_info { "Function '#{@name}' is ready for execution." }
    end

    to_enter :failed do |e|
      log_warn { "Function '#{@name}' failed: #{e}" }
      stop!
    end

    to_enter :stopped do
      log_info { "Function '#{@name}' is stopping" }
      stop!
    end

    to_enter :executing do |payload|
      @parent.with_timeout(@execution_timeout) do
        Base64.decode64(@process.query("#{Base64.encode64(payload)}\n"))
      rescue Async::TimeoutError
        log_warn { "Function '#{@name}' execution timed out" }
        stop
        raise ExecutionTimeoutError
      end
    end
  end

  READY = "READY"

  def initialize(name:, image:, ready_timeout: 5, execution_timeout: 10, parent: ::Async::Task.current)
    @name = name
    @image = image

    @ready_timeout = ready_timeout
    @execution_timeout = execution_timeout
    @parent = parent

    @process = TNCL::Docker::Runner.new(@image)
  end

  def start
    transit!(:ready)
    transit!(:idle)
  end

  def call(payload)
    transit!(:executing, args: [payload]).tap do
      transit!(:idle)
    end
  rescue TNCL::Machine::Machine::TransitionFailed
    raise NotRunningError
  end

  def stop
    transit!(:stopped) unless current_state == :stopped || current_state == :failed
  end

  private

  def stop!
    return unless @process.running?

    @process.kill
    wait
  end

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
    @process.wait_spawned
    m = read(timeout: @ready_timeout)

    return log_info { "Function '#{@name}' reported ready state." } if m == READY

    raise WrongReadyMessageError,
          "function '#{@name}': wrong ready message. Expected: '#{READY}', received: '#{m[0..80]}'"
  rescue ::Async::TimeoutError
    raise InitializationTimeoutError, "function '#{@name}': initialization timed out" if @process.running?
  rescue ::Async::Stop
    nil
  end

  def read_stderr
    @process.wait_spawned
    loop do
      output = read(from: :stderr)
      lines = output.split("\n")
      lines.each do |line|
        next parse_docker_error!(line) if line.start_with?("docker")

        log_info { "Function '#{@name}':  output: #{line}" }
      end
    end
  rescue ::Async::Stop, ::Async::TimeoutError
    nil
  end

  def wait_fail
    @process.wait_spawned
    begin
      @process.wait
    rescue StandardError
      nil
    end
    raise InitializationError, "funciton '#{name}': process quited"
  rescue ::Async::Stop
    nil
  end

  def wait_init(*tasks, stop_except: [])
    stop_except = [stop_except].flatten

    done, pending = TNCL::Async.wait_first(*tasks, parent: @parent)
    (pending - stop_except).each(&:stop).each(&:wait)
    done.wait
  end
end
