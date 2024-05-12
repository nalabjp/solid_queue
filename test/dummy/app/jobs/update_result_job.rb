class UpdateResultJob < ApplicationJob
  def perform(job_result, options = {})
    name      = options[:name] || raise(ArgumentError, 'missing keyword: :name')
    pause     = options[:pause]
    exception = options[:exception]

    job_result.status += "s#{name}"

    sleep(pause) if pause
    raise exception.new if exception

    job_result.status += "c#{name}"
    job_result.save!
  end
end
