class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.column :openid_url, :string
      t.column :nickname, :string
      t.column :fullname, :string
      t.column :uses_full_name, :boolean, :default => false
      t.column :homepage, :string
    end
  end

  def self.down
    drop_table :users
  end
end
