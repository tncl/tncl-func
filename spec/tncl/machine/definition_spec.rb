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
          expect { subject }.to change(definition, :default_state).from(nil).to(described_class::State)
          expect(definition.default_state).to eq(subject)
        end
      end

      context "when it's not the first added state" do
        let!(:first_state) { definition.state(:first_state) }

        it "adds the state to the definition" do
          expect { subject }.to change { definition.states[name] }.from(nil).to(described_class::State)
          expect(definition.states[name]).to eq(subject)
        end

        it "does not change the assigned default state" do
          expect { subject }.not_to change(definition, :default_state)
          expect(definition.default_state).to eq(first_state)
        end
      end
    end

    context "when state is already defined" do
      before do
        definition.state(name, final:)
      end

      include_examples "raises an exception", ArgumentError, "state 'state' is already defined"
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
end
