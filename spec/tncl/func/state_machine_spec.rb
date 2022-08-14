# frozen_string_literal: true

RSpec.describe TNCL::Func::StateMachine do
  let(:klass) do
    Class.new do
      extend TNCL::Func::StateMachine

      add_state_machine do
        state :created
        state :ready
        state :failed, final: true
        state :stopped, final: true
        state :executing, final: true

        transition from: [:created, :executing], to: :failed
        transition from: :created, to: :ready
        transition from: :ready, to: [:stopped, :executing]
        transition from: :executing, to: :ready
      end

      def start(fail: false)
        transit!(fail ? :failed : :ready)
      end
    end
  end

  let(:instance) { klass.new }

  shared_examples "returns state Definition" do
    it "returns an instance of Definition" do
      expect(subject).to be_an_instance_of(described_class::Definition)
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

  it "works" do
    # instance.current_state

    # instance.start
    # pp instance.current_state
    # instance.start
  end
end
