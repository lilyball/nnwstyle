class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :stylesheet
  
  validates_presence_of :body
  validates_presence_of :version
  validates_presence_of :stylesheet_id
  validates_presence_of :user_id
  
  validates_numericality_of :version
end
