# frozen_string_literal: true

class TNCL::Machine::Definition
  attr_reader :states, :transitions, :default_state

  class InvalidConfigError < StandardError; end

  class State
    attr_reader :name

    def initialize(name, final: false)
      @name = name
      @final = final
    end

    def final? = @final

    def ==(other) = @name == other.name && @final == other.final?
  end

  def initialize
    @states = {}
    @transitions = Hash.new { |h, k| h[k] = Set.new }
    @default_state = nil
  end

  def state?(name) = @states.include?(name)

  def state(name, final: false)
    state = State.new(name, final:)
    @default_state ||= state

    raise ArgumentError, "state '#{name}' is already defined" if state?(name)

    @states[name] = state
  end

  def transition(to:, from:)
    from = [from].flatten
    to = [to].flatten

    validate_transition!(from, to)

    from.product(to).each do |f, t|
      @transitions[f] << t
    end
  end

  def valid?
    validate!
    true
  rescue InvalidConfigError
    false
  end

  def validate!
    # TODO: check all states are reachable
    #
  end

  private

  def validate_transition!(from, to)
    unknown_states = (from + to).select{ !state?(_1) }
    raise ArgumentError, "states '#{unknown_states}' are unknown" if unknown_states.any?

    final_states = from.select{ @states[_1].final? }
    raise ArgumentError, "states '#{final_from_states}' are defined as 'final'" if final_states.any?
  end
end
