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

# Backport `ActiveJob::Base.successfully_enqueued` API
module SolidQueueActiveJobSuccessfullyEnqueuedBackport
  module Core
    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/core.rb#L51
    attr_writer :successfully_enqueued # :nodoc:

    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/core.rb#L53-L55
    def successfully_enqueued?
      @successfully_enqueued
    end

    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/core.rb#L58
    attr_accessor :enqueue_error
  end

  module Enqueueing
    def self.prepended(mod)
      # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/enqueuing.rb#L10
      mod.const_set(:EnqueueError, Class.new(StandardError))
    end

    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/enqueuing.rb#L58-L65
    def perform_later(*args)
      job = job_or_instantiate(*args)
      enqueue_result = job.enqueue

      yield job if block_given?

      enqueue_result
    end

    # https://github.com/rails/rails/blob/v7.1.3.2/activejob/lib/active_job/enqueuing.rb#L89-L110
    def enqueue(options = {})
      set(options)
      self.successfully_enqueued = false

      run_callbacks :enqueue do
        if scheduled_at
          queue_adapter.enqueue_at self, scheduled_at
        else
          queue_adapter.enqueue self
        end

        self.successfully_enqueued = true
      rescue EnqueueError => e
        self.enqueue_error = e
      end

      if successfully_enqueued?
        self
      else
        false
      end
    end
  end
end
ActiveJob::Base.include(SolidQueueActiveJobSuccessfullyEnqueuedBackport::Core)
ActiveJob.prepend(SolidQueueActiveJobSuccessfullyEnqueuedBackport::Enqueueing)

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
