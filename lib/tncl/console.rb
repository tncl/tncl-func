# frozen_string_literal: true

module TNCL::Console
  include ::Console

  [:debug, :info, :warn, :error, :fatal].each do |name|
    define_method("log_#{name}") do |*args, **params, &b|
      logger.public_send(name, self, *args, **params, &b)
    end
  end
end
