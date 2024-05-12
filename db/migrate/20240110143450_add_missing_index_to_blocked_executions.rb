class AddMissingIndexToBlockedExecutions < ActiveRecord::Migration[6.1]
  def change
    add_index :solid_queue_blocked_executions, [ :concurrency_key, :priority, :job_id ], name: "index_solid_queue_blocked_executions_for_release"
  end
end
