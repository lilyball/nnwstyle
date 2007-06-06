class CreateStylesheets < ActiveRecord::Migration
  def self.up
    create_table :stylesheets, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :name, :string
      t.column :description, :string
      t.column :version, :string, :default => '1.0'
      t.column :user_id, :integer
      t.column :created_at, :timestamp
      t.column :version_updated_at, :timestamp
    end
  end

  def self.down
    drop_table :stylesheets
  end
end
