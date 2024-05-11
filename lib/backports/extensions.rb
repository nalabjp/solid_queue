# Backport `Rails.error` API
module SolidQueueRailsErrorBackport

  # https://github.com/rails/rails/blob/v7.1.3.2/railties/lib/rails.rb#L90-L92
  # https://github.com/rails/rails/blob/v7.1.3.2/activesupport/lib/active_support.rb#L101-L102
  def error
    @_error ||= begin
                  require 'backports/active_support/isolated_execution_state.rb'
                  require 'backports/active_support/execution_context.rb'
                  require 'backports/active_support/error_reporter.rb'
                  ActiveSupport::ErrorReporter.new
                end
  end
end
Rails.extend(SolidQueueRailsErrorBackport)
