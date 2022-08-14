# frozen_string_literal: true

module TNCL::Machine::Machine
  class Error < TNCL::Func::Error; end

  class TransitionFailed < Error; end

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

    TNCL::Machine::Definition.new.tap do |definition|
      definition.instance_eval(&block)
      definition.validate!
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
