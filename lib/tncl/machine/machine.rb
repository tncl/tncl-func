# frozen_string_literal: true

module TNCL::Machine::Machine
  class Error < TNCL::Func::Error; end

  class TransitionFailed < Error; end

  module InstanceMethods
    private

    def transit!(new_state, args: [], params: {}, name: :state)
      definition = send("#{name}_definition")
      current = send("current_#{name}")
      available = definition.transitions[current]
      if available.include?(new_state)
        return run_on_enter(new_state, args:, params:, name:).tap do
          instance_variable_set("@current_#{name}", new_state) if available.include?(new_state)
        end
      end

      raise TransitionFailed,
            "cannot transit '#{name}' to '#{new_state}' from '#{current}'. Avaliable transitions: '#{available.to_a}'"
    end

    def run_on_enter(new_state, args:, params:, name:)
      enter_callback = public_send("#{name}_definition").enter_callbacks[new_state]
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

  def add_state_machine(name: :state, &block) # rubocop:disable Metrics/MethodLength
    @state_machines ||= {}
    raise ArgumentError, "machine '#{name}' is already defined" if @state_machines[name]

    TNCL::Machine::Definition.new(name).tap do |definition|
      definition.instance_exec(&block)
      definition.validate!
      definition_method = "#{name}_definition"

      [self.class, self].each do |target|
        target.define_method(definition_method) do
          definition
        end
      end

      define_method("current_#{name}") do
        var_name = :"@current_#{name}"
        current_value = instance_variable_get(var_name)
        return current_value if current_value

        instance_variable_set(var_name, definition.default_state)
      end
      @state_machines[name] = definition
    end
  end
end
