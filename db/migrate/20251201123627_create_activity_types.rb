class CreateActivityTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_types do |t|
      t.string :name

      t.timestamps
    end
  end
end
