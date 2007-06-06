class CreateResources < ActiveRecord::Migration
  def self.up
    create_table :resources, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :data, :binary
      t.column :name, :string
      t.column :mimeType, :string
      t.column :stylesheet_id, :integer
      t.column :updated_at, :timestamp
    end
  end

  def self.down
    drop_table :resources
  end
end
