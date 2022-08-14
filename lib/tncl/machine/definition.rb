# frozen_string_literal: true

class TNCL::Machine::Definition
  attr_reader :states, :transitions, :default_state, :groups

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
    @groups = {}
  end

  def state(name, final: false)
    state = State.new(name, final:)
    raise ArgumentError, "default state '#{name}' cannot be final" if @default_state.nil? && state.final?

    @default_state ||= state.name

    raise ArgumentError, "state '#{name}' is already defined" if @states.include?(name)

    @states[name] = state
  end

  def transition(to:, from:)
    from = [from].flatten
    to = [to].flatten

    validate_transition!(from, to)

    from.product(to).each { @transitions[_1] << _2 }
  end

  def group(name, *states)
    raise ArgumentError, "group '#{name}' is already defined" if @groups.include?(name)
    raise ArgumentError, "group cannot be empty" if states.empty?

    unknown_states = states.select{ !@states.include?(_1) }
    raise ArgumentError, "states '#{unknown_states}' are unknown" if unknown_states.any?

    states.each do |state|
      @groups.each do |group, group_states|
        raise ArgumentError, "state '#{state}' is already included in group '#{group}'" if group_states.include?(state)
      end
    end

    @groups[name] = states.to_set
  end

  def valid?
    validate!
    true
  rescue InvalidConfigError
    false
  end

  def validate!
    validate_states!
    validate_state_reachability!
    validate_transitive_states!
  end

  private

  def validate_transition!(from, to)
    unknown_states = (from + to).select{ !@states.include?(_1) }
    raise ArgumentError, "states '#{unknown_states}' are unknown" if unknown_states.any?

    final_states = from.select{ @states[_1].final? }
    raise ArgumentError, "states '#{final_states}' are defined as 'final'" if final_states.any?
  end

  def validate_states!
    raise InvalidConfigError, "no states defined" if @states.empty?
  end

  def validate_state_reachability!
    reachable_states = @transitions.values.reduce(&:+).to_a + [@default_state] # rubocop:disable Performance/Sum
    unreachable_states = @states.values.map(&:name).select{ !reachable_states.include?(_1) } # TODO: optimize me
    return unless unreachable_states.any?

    return unless unreachable_states.any?

    raise InvalidConfigError, "states '#{unreachable_states}' are not reachable"
  end

  def validate_transitive_states!
    transitive_states = @states.values.reject(&:final?).select{ @transitions[_1.name].empty? }.map(&:name)
    return unless transitive_states.any?

    raise InvalidConfigError, "transitive states '#{transitive_states}' have no outgoing transitions"
  end
end
