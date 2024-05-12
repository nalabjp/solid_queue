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

# Backport `ActiveRecord::Result.empty` API
module SolidQueueActiveRecordInsertAllBackport
  def insert_all(attributes, **_options)
    if attributes.empty?
      # https://github.com/rails/rails/blob/v6.1.7.7/activerecord/lib/active_record/insert_all.rb#L11
      # In AR 6.1.7.7, it raises ArgumentError when `inserts` argument is blank.
      #
      # https://github.com/rails/rails/blob/v7.1.3.2/activerecord/lib/active_record/insert_all.rb#L42
      # But in AR 7.1.3.2, it returns `ActiveRecord::Result.empty`.
      #
      # https://github.com/rails/rails/blob/v7.1.3.2/activerecord/lib/active_record/result.rb#L41-L47
      # https://github.com/rails/rails/blob/v7.1.3.2/activerecord/lib/active_record/result.rb#L195
      ActiveRecord::Result.new([].freeze, [].freeze, {}.freeze).freeze
    else
      super
    end
  end
end
ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.extend(SolidQueueActiveRecordInsertAllBackport)
end
