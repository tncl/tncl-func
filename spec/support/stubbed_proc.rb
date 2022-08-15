# frozen_string_literal: true

class StubbedProc
  attr_reader :args, :params, :block, :result, :error

  def initialize(&block)
    @block = block
  end

  def called? = @called

  def to_proc
    blk = @block
    cld_method = method(:called)
    cld = @called

    lambda do |*args, **params, &block|
      raise "#{self.class.name} can only be called once" if cld

      result = blk.call(*args, **params, &block)
      cld_method.call(args, params, block, result)
    rescue StandardError => e
      cld_method.call(args, params, block, nil, e)
      raise
    end
  end

  private

  def called(args, params, block, result, error = nil)
    @called = true
    @args = args
    @params = params
    @block = block
    @result = result
    @error = error
  end
end
