class Resource < ActiveRecord::Base
  belongs_to :stylesheet
  
  validates_presence_of :data
  validates_presence_of :name
  validates_presence_of :stylesheet_id
  
  validates_uniqueness_of :name, :scope => :stylesheet_id, :case_sensitive => false
end
