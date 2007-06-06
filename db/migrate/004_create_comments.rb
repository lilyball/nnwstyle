class CreateComments < ActiveRecord::Migration
  def self.up
    create_table :comments, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :body, :text, :limit => 5120
      t.column :rating, :integer
      t.column :version, :string
      t.column :stylesheet_id, :integer
      t.column :user_id, :integer
      t.column :created_at, :timestamp
    end
  end

  def self.down
    drop_table :comments
  end
end
