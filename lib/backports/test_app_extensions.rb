# Backport `stub_const` API
require 'backports/active_support/testing/constant_stubbing.rb'
ActiveSupport::TestCase.include(ActiveSupport::Testing::ConstantStubbing)

# Backport `ActiveJob::Base.set` API
module SolidQueueActiveJobCoreBackport
  # Partial backport from `v7.1.3.2`
  # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/core.rb#L168-L175
  def set(options = {})
    self.scheduled_at = options[:wait].seconds.from_now if options[:wait]
    self.scheduled_at = options[:wait_until] if options[:wait_until]
    self.queue_name   = self.class.queue_name_from_part(options[:queue]) if options[:queue]
    self.priority     = options[:priority].to_i if options[:priority]

    self
  end
end
ActiveJob::Base.include(SolidQueueActiveJobCoreBackport)

module SolidQueueActiveJobConfiguredJobBackport
  # Partial backport from `v7.1.3.2`
  # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/configured_job.rb#L10-L12
  # https://github.com/rails/rails/blob/v6.1.7.7/activejob/lib/active_job/configured_job.rb#L10-L12
  def perform_now(*args)
    @job_class.new(*args).set(@options).perform_now
  end
end
ActiveJob::ConfiguredJob.prepend(SolidQueueActiveJobConfiguredJobBackport)
