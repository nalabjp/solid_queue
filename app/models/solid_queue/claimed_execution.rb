# frozen_string_literal: true

class SolidQueue::ClaimedExecution < SolidQueue::Execution
  belongs_to :process

  class Result < Struct.new(:success, :error)
    def success?
      success
    end
  end

  class << self
    def claiming(job_ids, process_id, &block)
      now = Time.current
      job_data = Array(job_ids).collect { |job_id| { job_id: job_id, process_id: process_id, created_at: now } }

      insert_all!(job_data)
      where(job_id: job_ids, process_id: process_id).load.tap do |claimed|
        block.call(claimed)
      end
    end

    def release_all
      includes(:job).each(&:release)
    end

    def discard_all_in_batches(*)
      raise UndiscardableError, "Can't discard jobs in progress"
    end

    def discard_all_from_jobs(*)
      raise UndiscardableError, "Can't discard jobs in progress"
    end
  end

  def perform
    result = execute

    if result.success?
      finished
    else
      failed_with(result.error)
    end
  ensure
    job.unblock_next_blocked_job
  end

  def release
    transaction do
      job.dispatch_bypassing_concurrency_limits
      destroy!
    end
  end

  def discard
    raise UndiscardableError, "Can't discard a job in progress"
  end

  private
    def execute
      ActiveJob::Base.execute(job.arguments)
      Result.new(true, nil)
    rescue Exception => e
      Result.new(false, e)
    end

    def finished
      transaction do
        job.finished!
        destroy!
      end
    end

    def failed_with(error)
      transaction do
        job.failed_with(error)
        destroy!
      end
    end
end
