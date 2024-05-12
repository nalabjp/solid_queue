# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
require "rails/test_help"
require "debug"
require "mocha/minitest"
require "backports/test_app_extensions.rb"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

module BlockLogDeviceTimeoutExceptions
  def write(...)
    # Prevents Timeout exceptions from occurring during log writing, where they will be swallowed
    # See https://bugs.ruby-lang.org/issues/9115
    Thread.handle_interrupt(Timeout::Error => :never, Timeout::ExitException => :never) { super }
  end
end

Logger::LogDevice.prepend(BlockLogDeviceTimeoutExceptions)

class ActiveSupport::TestCase
  teardown do
    JobBuffer.clear

    if SolidQueue.supervisor_pidfile && File.exist?(SolidQueue.supervisor_pidfile)
      File.delete(SolidQueue.supervisor_pidfile)
    end
  end

  private
    def wait_for_jobs_to_finish_for(timeout = 1.second)
      wait_while_with_timeout(timeout) { SolidQueue::Job.where(finished_at: nil).any? }
    end

    def assert_no_pending_jobs
      skip_active_record_query_cache do
        assert SolidQueue::Job.where(finished_at: nil).none?
      end
    end

    def run_supervisor_as_fork(**options)
      fork do
        SolidQueue::Supervisor.start(**options)
      end
    end

    def wait_for_registered_processes(count, timeout: 1.second)
      wait_while_with_timeout(timeout) { SolidQueue::Process.count != count }
    end

    def assert_no_registered_processes
      skip_active_record_query_cache do
        assert SolidQueue::Process.none?
      end
    end

    def find_processes_registered_as(kind)
      skip_active_record_query_cache do
        SolidQueue::Process.where(kind: kind)
      end
    end

    def terminate_process(pid, timeout: 10, signal: :TERM)
      signal_process(pid, signal)
      wait_for_process_termination_with_timeout(pid, timeout: timeout)
    end

    def wait_for_process_termination_with_timeout(pid, timeout: 10, exitstatus: 0)
      Timeout.timeout(timeout) do
        if process_exists?(pid)
          Process.waitpid(pid)
          assert exitstatus, $?.exitstatus
        end
      end
    rescue Timeout::Error
      signal_process(pid, :KILL)
      raise
    end

    def wait_while_with_timeout(timeout, &block)
      Timeout.timeout(timeout) do
        skip_active_record_query_cache do
          while block.call
            sleep 0.05
          end
        end
      end
    rescue Timeout::Error
    end

    def signal_process(pid, signal, wait: nil)
      Thread.new do
        sleep(wait) if wait
        Process.kill(signal, pid)
      end
    end

    def process_exists?(pid)
      reap_processes
      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end

    def reap_processes
      Process.waitpid(-1, Process::WNOHANG)
    rescue Errno::ECHILD
    end

    # Allow skipping AR query cache, necessary when running test code in multiple
    # forks. The queries done in the test might be cached and if we don't perform
    # any non-SELECT queries after previous SELECT queries were cached on the connection
    # used in the test, the cache will still apply, even though the data returned
    # by the cached queries might have been updated, created or deleted in the forked
    # processes.
    def skip_active_record_query_cache(&block)
      SolidQueue::Record.uncached(&block)
    end
end
