class SequentialUpdateResultJob < UpdateResultJob
  limits_concurrency key: ->(job_result, *_) { job_result }
end
