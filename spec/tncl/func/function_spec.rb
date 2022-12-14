# frozen_string_literal: true

RSpec.describe TNCL::Func::Function, timeout: 15 do
  let(:function) { described_class.new(name:, image:, ready_timeout: 1, execution_timeout: 1) }
  let(:name) { image }

  after do
    function.stop
  end

  shared_examples "moves to stopped state" do
    it "moves to stopped state" do
      begin
        subject
      rescue StandardError
        nil
      end

      expect(function.stopped?).to be(true)
    end
  end

  shared_examples "moves to ready state" do
    it "moves to ready state" do
      begin
        subject
      rescue StandardError
        nil
      end

      expect(function.ready?).to be(true)
    end
  end

  describe "#start" do
    subject { function.start }

    context "when image exists" do
      context "when container works properly" do
        let(:image) { "echo" }

        include_examples "does not raise any exceptions"
        include_examples "moves to ready state"
      end

      context "when container prints wrong READY message" do
        let(:image) { "ready_error" }

        include_examples "raises an exception", described_class::WrongReadyMessageError,
                         "function 'ready_error': wrong ready message. Expected: 'READY', received: 'BLAH BLAH'"

        include_examples "moves to stopped state"
      end

      context "when container does not print READY in time" do
        let(:image) { "ready_timeout" }

        include_examples "raises an exception", described_class::InitializationTimeoutError,
                         "function 'ready_timeout': initialization timed out"
        include_examples "moves to stopped state"
      end

      context "when container initialization fails" do
        let(:image) { "init_fail" }

        include_examples "raises an exception", described_class::InitializationError,
                         "funciton 'init_fail': process quited"
        include_examples "moves to stopped state"
      end
    end

    context "when image does not exist" do
      let(:image) { "image-does-not-exist" }

      include_examples "raises an exception", described_class::ImageNotFoundError,
                       "function 'image-does-not-exist': image 'image-does-not-exist' is not found"
      include_examples "moves to stopped state"
    end
  end

  describe "#call" do
    subject { function.call("payload") }

    context "when initialized successfully" do
      let(:image) { "echo" }

      before do
        function.start
      end

      it "returns results of function execution" do
        Array.new(10) { SecureRandom.uuid }.each do |load|
          expect(function.call(load)).to eq(load)
        end
      end

      include_examples "moves to ready state"
    end

    context "when initialization failed" do
      let(:image) { "image-does-not-exist" }

      before do
        function.start
      rescue StandardError
        nil
      end

      include_examples "raises an exception", described_class::NotRunningError
    end

    context "when execution times out" do
      let(:image) { "execution_timeout" }

      before do
        function.start
      end

      include_examples "raises an exception", described_class::ExecutionTimeoutError
      include_examples "moves to stopped state"
    end
  end
end
