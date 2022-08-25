# frozen_string_literal: true

class TNCL::Machine::Definition
  attr_reader :states, :transitions, :default_state, :groups, :enter_callbacks

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

  class Callback
    attr_reader :on_fail, :block

    def initialize(on_fail: nil, &block)
      @on_fail = on_fail || ->(*, **) {}
      @block = block
    end
  end

  def initialize(name)
    @name = name
    @states = {}
    @transitions = Hash.new { |h, k| h[k] = Set.new }
    @default_state = nil
    @groups = {}
    @enter_callbacks = {}
  end

  def state(name, final: false)
    state = State.new(name, final:)
    raise ArgumentError, "default state '#{name}' cannot be final" if @default_state.nil? && state.final?

    @default_state ||= state.name

    raise ArgumentError, "state name '#{name}' is already taken by a group" if @groups.include?(name)

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
    validate_group!(name)
    validate_group_states!(states)

    @groups[name] = states.to_set
  end

  # TODO: state != on_fail
  def to_enter(state, on_fail: nil, &block)
    raise ArgumentError, "state '#{state}' already has a to_enter callback" if @enter_callbacks.include?(state)
    raise ArgumentError, "state '#{state}' is unknown" unless @states.include?(state)

    name = @name
    on_fail_state = on_fail

    on_fail = ->(e) { transit!(on_fail_state, name:, args: [e]) } if on_fail.is_a?(Symbol)

    @enter_callbacks[state] = Callback.new(on_fail:, &block)
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
    # TODO: at least one final state must be defined
  end

  private

  def validate_group!(name)
    raise ArgumentError, "group name '#{name}' is already taken by a state" if @states.include?(name)
    raise ArgumentError, "group '#{name}' is already defined" if @groups.include?(name)
  end

  def validate_group_states!(states)
    raise ArgumentError, "group cannot be empty" if states.empty?

    unknown_states = states.select{ !@states.include?(_1) }
    raise ArgumentError, "states '#{unknown_states}' are unknown" if unknown_states.any?

    states.each do |state|
      @groups.each do |group, group_states|
        raise ArgumentError, "state '#{state}' is already included in group '#{group}'" if group_states.include?(state)
      end
    end
  end

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

    raise InvalidConfigError, "states '#{unreachable_states}' are not reachable"
  end

  def validate_transitive_states!
    transitive_states = @states.values.reject(&:final?).select{ @transitions[_1.name].empty? }.map(&:name)
    return unless transitive_states.any?

    raise InvalidConfigError, "transitive states '#{transitive_states}' have no outgoing transitions"
  end
end
