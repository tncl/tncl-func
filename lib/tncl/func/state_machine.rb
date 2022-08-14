# frozen_string_literal: true

module TNCL::Func::StateMachine
  class Error < TNCL::Func::Error; end

  class TransitionFailed < Error; end

  class Definition
    attr_reader :states, :transitions, :default_state

    class State
      attr_reader :name, :final

      def initialize(name, final: false)
        @name = name
        @final = final
      end
    end

    def initialize
      @states = {}
      @transitions = Hash.new { |h, k| h[k] = Set.new }
      @default_state = nil
    end

    def state(name, final: false)
      state = State.new(name, final:)
      @default_state ||= state

      raise ArgumentError, "state '#{name}' already defined" if @states.key?(name)

      @states[name] = state
    end

    def transition(from: @states, to: @states)
      from = [from].flatten
      to = [to].flatten

      unknown_states = (from + to).select{ !state?(_1) }

      raise ArgumentError, "states '#{unknown_states}' are unknown" if unknown_states.any?

      from.each do |f|
        to.each do |t|
          @transitions[f] << t
        end
      end
    end

    def state?(name)
      @states.include?(name)
    end
  end

  module InstanceMethods
    private

    def transit!(new_state, name: :state)
      definition = send("#{name}_definition")
      current = send("current_#{name}")
      available = definition.transitions[current]
      return instance_variable_set("@current_#{name}", new_state) if available.include?(new_state)

      raise TransitionFailed,
            "cannot transit '#{name}' to '#{new_state}' from '#{current}'. Avaliable states: '#{available.to_a}'"
    end
  end

  def self.extended(base)
    base.include(InstanceMethods)
  end

  private

  def add_state_machine(name: :state, &block) # rubocop:disable Metrics/MethodLength
    @state_machines ||= {}
    raise ArgumentError, "machine '#{name}' is already defined" if @state_machines[name]

    Definition.new.tap do |definition|
      definition.instance_eval(&block)
      definition_method = "#{name}_definition"

      self.class.define_method definition_method do
        definition
      end

      define_method definition_method do
        definition
      end

      define_method "current_#{name}" do
        var_name = :"@current_#{name}"
        current_value = instance_variable_get(var_name)
        return current_value if current_value

        instance_variable_set(var_name, definition.default_state)
      end
      @state_machines[name] = definition
    end
  end
end
