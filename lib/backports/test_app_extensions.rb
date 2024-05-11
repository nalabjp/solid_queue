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

# Backport `ActiveJob.perform_all_later` API
module SolidQueueActiveJobPerformAllLaterBackport
  module ConfiguredJob
    # Partial backport from `v7.1.3.2`
    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/configured_job.rb#L18-L20
    def perform_all_later(multi_args)
      @job_class.perform_all_later(multi_args, options: @options)
    end
  end

  module Enqueueing
    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/enqueuing.rb#L16-L39
    def perform_all_later(*jobs)
      jobs.flatten!
      jobs.group_by(&:queue_adapter).each do |queue_adapter, adapter_jobs|
        instrument_enqueue_all(queue_adapter, adapter_jobs) do
          if queue_adapter.respond_to?(:enqueue_all)
            queue_adapter.enqueue_all(adapter_jobs)
          else
            adapter_jobs.each do |job|
              job.successfully_enqueued = false
              if job.scheduled_at
                queue_adapter.enqueue_at(job, job.scheduled_at)
              else
                queue_adapter.enqueue(job)
              end
              job.successfully_enqueued = true
            rescue EnqueueError => e
              job.enqueue_error = e
            end
          end
        end
      end
      nil
    end
  end

  module Instrumentation
    private

    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/instrumentation.rb#L4-L12
    def instrument_enqueue_all(queue_adapter, jobs)
      payload = { adapter: queue_adapter, jobs: jobs }
      ActiveSupport::Notifications.instrument("enqueue_all.active_job", payload) do
        result = yield payload
        payload[:enqueued_count] = result
        result
      end
    end
  end
end
ActiveJob::ConfiguredJob.include(SolidQueueActiveJobPerformAllLaterBackport::ConfiguredJob)
ActiveJob.extend(SolidQueueActiveJobPerformAllLaterBackport::Enqueueing)
ActiveJob.extend(SolidQueueActiveJobPerformAllLaterBackport::Instrumentation)
