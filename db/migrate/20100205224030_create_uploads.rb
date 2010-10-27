class CreateUploads < ActiveRecord::Migration
  def self.up
    create_table :uploads do |t|
      t.column :source, :string
      t.column :file_path, :string
      t.column :content_type, :string
      t.column :rating, :character, :null => false
      t.column :uploader_id, :integer, :null => false
      t.column :uploader_ip_addr, "inet", :null => false
      t.column :tag_string, :text, :null => false
      t.column :status, :string, :null => false, :default => "pending"
      t.column :post_id, :integer
      t.column :md5_confirmation, :string
      t.timestamps
    end
  end

  def self.down
    drop_table :uploads
  end
end