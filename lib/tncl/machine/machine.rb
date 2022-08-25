# frozen_string_literal: true

module TNCL::Machine::Machine
  class Error < TNCL::Func::Error; end

  class TransitionFailed < Error; end

  module InstanceMethods
    private

    def current_state
      return @current_state if @current_state

      @current_state = state_definition.default_state
    end

    def current_state_group
      state_definition.groups.find{ _2.include?(current_state) }&.first
    end

    def transit!(new_state, args: [], params: {})
      available = state_definition.transitions[current_state]
      if available.include?(new_state)
        return run_on_enter(new_state, args:, params:).tap do
          @current_state = new_state if available.include?(new_state)
        end
      end

      raise TransitionFailed,
            "cannot transit state to '#{new_state}' from '#{current_state}'. Avaliable transitions: '#{available.to_a}'"
    end

    def run_on_enter(new_state, args:, params:)
      enter_callback = state_definition.enter_callbacks[new_state]
      return if enter_callback.nil?

      instance_exec(*args, **params, &enter_callback.block)
    rescue StandardError => e
      instance_exec(e, &enter_callback.on_fail)
      raise
    end
  end

  def self.extended(base)
    base.include(InstanceMethods)
  end

  private

  def add_state_machine(name: :state, &block)
    raise ArgumentError, "machine '#{name}' is already defined" if @state_definition

    @state_definition = TNCL::Machine::Definition.new(name).tap do |definition|
      definition.instance_exec(&block)
      definition.validate!

      define_method(:state_definition) do
        definition
      end
    end
  end
end
