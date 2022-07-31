# frozen_string_literal: true

module TNCL
  module Async
    def self.wait_first(*tasks, parent: ::Async::Task.current)
      c = ::Async::Notification.new

      await = lambda do |task|
        parent.async do
          task.wait
          c.signal(task)
        rescue StandardError
          c.signal(task)
        end
      end

      tasks.each(&await)

      c.wait.yield_self { [_1, tasks - [_1]] }
    end
  end
end
