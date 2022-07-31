# frozen_string_literal: true

RSpec.shared_examples "raises an exception" do |exception, message|
  it "raises #{exception.name}" do
    expect { subject }.to raise_error(exception, message)
  end
end

RSpec.shared_examples "does not raise any exceptions" do
  it "does not raise any exceptions" do
    expect { subject }.not_to raise_error
  end
end
