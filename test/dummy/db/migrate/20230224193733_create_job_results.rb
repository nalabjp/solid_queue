class CreateJobResults < ActiveRecord::Migration[6.1]
  def change
    create_table :job_results do |t|
      t.string :queue_name
      t.string :status
      t.string :value
      t.timestamps
    end
  end
end
