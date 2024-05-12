class StoreResultJob < ApplicationJob
  queue_as :background

  def perform(value, options = {})
    status    = options[:status] || :completed
    pause     = options[:pause]
    exception = options[:exception]
    exit      = options[:exit]

    result = JobResult.create!(queue_name: queue_name, status: "started", value: value)

    sleep(pause) if pause
    raise exception.new if exception
    exit! if exit

    result.update!(status: status)
  end
end
