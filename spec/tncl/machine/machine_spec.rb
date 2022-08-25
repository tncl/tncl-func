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

      public :transit! # make private `transit!` public to simplify testing
    end
  end
  let(:instance) { klass.new }
  let(:on_fail) { nil }
  let(:on_ready_block) { -> {} }

  shared_examples "returns state Definition" do
    it "returns an instance of Definition" do
      expect(subject).to be_an_instance_of(TNCL::Machine::Definition)
    end
  end

  describe ".state_definition" do
    subject { klass.state_definition }

    include_examples "returns state Definition"
  end

  describe "#state_definition" do
    subject { instance.state_definition }

    include_examples "returns state Definition"
  end

  describe ".transit!" do
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

        it "calls on_enter callback" do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
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

          it "calls on_enter callback" do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
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

          it "calls on_enter callback" do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
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
                       "cannot transit state to 'paused' from 'created'. Avaliable transitions: '[:failed, :ready]'"
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
