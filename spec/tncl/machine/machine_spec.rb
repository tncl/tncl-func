# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe TNCL::Machine::Machine do
  let(:klass) do
    of = on_fail
    orb = on_ready_block
    Class.new do
      extend TNCL::Machine::Machine

      add_state_machine do
        state :created
        state :ready
        state :failed, final: true
        state :stopped, final: true
        state :executing
        state :paused

        group :terminated, :stopped, :failed

        transition from: [:created, :executing], to: :failed
        transition from: :created, to: :ready
        transition from: :ready, to: [:stopped, :executing, :paused]
        transition from: [:paused, :executing], to: :ready

        to_enter :ready, on_fail: of, &orb
      end

      # make some private methods public for testing
      public :transit!
      public :current_state_group
      public :current_state
      public :state_definition
      public :in_state?
    end
  end
  let(:instance) { klass.new }
  let(:on_fail) { nil }
  let(:on_ready_block) { -> {} }

  describe "#current_state_group" do
    subject { instance.current_state_group }

    context "when current state is not in a group" do
      include_examples "returns nil"
    end

    context "when current state is in a group" do
      before do
        instance.transit!(:failed)
      end

      it "returns group name" do
        expect(subject).to eq(:terminated)
      end
    end
  end

  describe "#in_state?" do
    subject { instance.in_state?(name) }

    context "when name is a state" do
      context "when machine is in state" do
        let(:name) { :created }

        include_examples "returns true"
      end

      context "when machine is not in state" do
        let(:name) { :failed }

        include_examples "returns false"
      end
    end

    context "when name is a group" do
      let(:name) { :terminated }

      context "when machine is in state in group" do
        before do
          instance.transit!(:failed)
        end

        include_examples "returns true"
      end

      context "when machine is not in state in group" do
        include_examples "returns false"
      end
    end

    context "when state or group is unknown" do
      let(:name) { "unknown" }

      include_examples "raises an exception", ArgumentError, "Unknown group or state 'unknown'. Available states: '[:created, :ready, :failed, :stopped, :executing, :paused]'. Available groups: '[:terminated]'" # rubocop:disable Layout/LineLength
    end
  end

  describe "#transit!" do
    subject { instance.transit!(new_state, args:, params:) }

    let(:args) { [:arg] }
    let(:params) { { key: :value } }

    context "when new state is allowed" do
      let(:new_state) { :ready }

      context "when to_enter callback does not fail" do
        let(:on_ready_block) { StubbedProc.new { |arg, key:| [arg, key] } }

        it "updates the state" do
          expect { subject }.to change(instance, :current_state).from(:created).to(:ready)
        end

        it "calls on_enter callback" do # rubocop:disable RSpec/MultipleExpectations
          subject
          expect(on_ready_block).to be_called
          expect(on_ready_block.args).to eq(args)
          expect(on_ready_block.params).to eq(params)
          expect(on_ready_block.result).to eq([:arg, :value])
          expect(on_ready_block.error).to be_nil
        end
      end

      context "when to_enter callback fails" do
        let(:on_ready_block) { StubbedProc.new { |_arg, key:| raise "test error" } } # rubocop:disable Lint/UnusedBlockArgument

        context "when on_fail is nil" do
          include_examples "raises an exception", RuntimeError, "test error"

          it "calls on_enter callback" do # rubocop:disable RSpec/MultipleExpectations
            subject rescue nil # rubocop:disable Style/RescueModifier
            expect(on_ready_block).to be_called
            expect(on_ready_block.args).to eq(args)
            expect(on_ready_block.params).to eq(params)
            expect(on_ready_block.result).to be_nil
            expect(on_ready_block.error).to be_an_instance_of(RuntimeError)
          end

          it "does not change the state" do
            expect { subject rescue nil }.not_to change(instance, :current_state) # rubocop:disable Style/RescueModifier
          end
        end

        context "when on_fail is :failed" do
          let(:on_fail) { :failed }

          include_examples "raises an exception", RuntimeError, "test error"

          it "calls on_enter callback" do # rubocop:disable RSpec/MultipleExpectations
            subject rescue nil # rubocop:disable Style/RescueModifier
            expect(on_ready_block).to be_called
            expect(on_ready_block.args).to eq(args)
            expect(on_ready_block.params).to eq(params)
            expect(on_ready_block.result).to be_nil
            expect(on_ready_block.error).to be_an_instance_of(RuntimeError)
          end

          it "changes the state" do
            expect { subject rescue nil }.to change(instance, :current_state).from(:created).to(:failed) # rubocop:disable Style/RescueModifier
          end
        end
      end
    end

    context "when new state is not allowed" do
      let(:new_state) { :paused }

      include_examples "raises an exception", TNCL::Machine::Machine::TransitionFailed,
                       "cannot transit state to 'paused' from 'created'. Possible transitions: '[:failed, :ready]'"
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
