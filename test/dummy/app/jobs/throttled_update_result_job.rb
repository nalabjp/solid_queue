class ThrottledUpdateResultJob < UpdateResultJob
  limits_concurrency to: 3, key: ->(job_result, *_) { job_result }
end
