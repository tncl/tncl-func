# frozen_string_literal: true

RSpec.describe TNCL::Machine::Definition do
  let(:definition) { described_class.new }

  describe "#state" do
    subject { definition.state(name, final:) }

    let(:name) { :state }
    let(:final) { false }

    context "when state is not yet defined" do
      context "when it's the first added state" do
        it "adds the state to the definition" do
          expect { subject }.to change { definition.states[name] }.from(nil).to(described_class::State)
          expect(definition.states[name]).to eq(subject)
        end

        it "assigns default_state" do
          expect { subject }.to change(definition, :default_state).from(nil).to(:state)
        end
      end

      context "when it's not the first added state" do
        before do
          definition.state(:first_state)
        end

        it "adds the state to the definition" do
          expect { subject }.to change { definition.states[name] }.from(nil).to(described_class::State)
          expect(definition.states[name]).to eq(subject)
        end

        it "does not change the assigned default state" do
          expect { subject }.not_to change(definition, :default_state)
        end
      end
    end

    context "when state is already defined" do
      before do
        definition.state(name, final:)
      end

      include_examples "raises an exception", ArgumentError, "state 'state' is already defined"
    end

    context "when default state is final" do
      let(:final) { true }

      include_examples "raises an exception", ArgumentError, "default state 'state' cannot be final"
    end
  end

  describe "#transition" do
    subject { definition.transition(from:, to:) }

    before do
      definition.state :first_state
      definition.state :second_state
      definition.state :third_state, final: true
      definition.state :fourth_state, final: true
    end

    context "when from and to are arrays" do
      let(:from) { [:first_state, :second_state] }
      let(:to) { [:third_state, :fourth_state] }

      it "creates all transitions" do
        expect do
          subject
        end.to(change { definition.transitions[:first_state].to_a.sort }.from([]).to([:fourth_state, :third_state])
          .and(change { definition.transitions[:second_state].to_a.sort }.from([]).to([:fourth_state, :third_state])))
      end
    end

    context "when from and to are single values" do
      let(:from) { :first_state }
      let(:to) { :second_state }

      it "creates a transition" do
        expect do
          subject
        end.to(change { definition.transitions[:first_state].to_a.sort }.from([]).to([:second_state]))
      end
    end

    context "when from is an unknown state" do
      let(:from) { :unknown }
      let(:to) { :second_state }

      include_examples "raises an exception", ArgumentError, "states '[:unknown]' are unknown"
    end

    context "when to is an unknown state" do
      let(:from) { :first_state }
      let(:to) { :unknown }

      include_examples "raises an exception", ArgumentError, "states '[:unknown]' are unknown"
    end

    context "when from is a final state" do
      let(:from) { :third_state }
      let(:to) { :second_state }

      include_examples "raises an exception", ArgumentError, "states '[:third_state]' are defined as 'final'"
    end
  end

  describe "#valid?" do
    subject { definition.valid? }

    context "when definition is valid" do
      before do
        definition.state :initial_state
        definition.state :final_state, final: true

        definition.transition from: :initial_state, to: :final_state
      end

      it "returns true" do
        expect(subject).to be_truthy
      end
    end

    context "when definition is invalid" do
      it "returns false" do
        expect(subject).to be_falsey
      end
    end
  end

  describe "#group" do
    subject { definition.group(name, *states) }

    let(:name) { :group }
    let(:states) { [:initial_state, :final_state] }

    before do
      definition.state :initial_state
      definition.state :final_state, final: true

      definition.transition from: :initial_state, to: :final_state
    end

    context "when group is not yet defined" do
      context "when states are not in other groups" do
        it "adds a new group" do
          expect { subject }.to change { definition.groups[name] }.from(nil).to([:initial_state, :final_state].to_set)
        end
      end

      context "when states are in other groups" do
        before do
          definition.group :another_group, :final_state
        end

        include_examples "raises an exception",
                         ArgumentError,
                         "state 'final_state' is already included in group 'another_group'"
      end

      context "when states are unknown" do
        let(:states) { [:unknown] }

        include_examples "raises an exception", ArgumentError, "states '[:unknown]' are unknown"
      end
    end

    context "when group is already defined" do
      before do
        definition.group(name, *states)
      end

      include_examples "raises an exception", ArgumentError, "group 'group' is already defined"
    end
  end

  describe "#validate!" do
    subject { definition.validate! }

    context "when definition is valid" do
      before do
        definition.state :initial_state
        definition.state :final_state, final: true

        definition.transition from: :initial_state, to: :final_state
      end

      include_examples "does not raise any exceptions"
    end

    context "when definition is invalid" do
      context "when no states defined" do
        include_examples "raises an exception",
                         described_class::InvalidConfigError,
                         "no states defined"
      end

      context "when only default state is defined" do
        before do
          definition.state :initial_state
        end

        include_examples "raises an exception",
                         described_class::InvalidConfigError,
                         "transitive states '[:initial_state]' have no outgoing transitions"
      end

      context "when no all states are reachable" do
        before do
          definition.state :initial_state
          definition.state :final_state, final: true
        end

        include_examples "raises an exception",
                         described_class::InvalidConfigError,
                         "states '[:final_state]' are not reachable"
      end

      context "when a transitive state does not have outgoing transitions" do
        before do
          definition.state :initial_state
          definition.state :transitive_state
          definition.state :final_state, final: true

          definition.transition from: :initial_state, to: [:transitive_state, :final_state]
        end

        include_examples "raises an exception",
                         described_class::InvalidConfigError,
                         "transitive states '[:transitive_state]' have no outgoing transitions"
      end

      context "when a state is unreachable" do
        before do
          definition.state :initial_state
          definition.state :transitive_state
          definition.state :final_state, final: true

          definition.transition from: :initial_state, to: [:transitive_state]
        end

        include_examples "raises an exception",
                         described_class::InvalidConfigError,
                         "states '[:final_state]' are not reachable"
      end
    end
  end
end
