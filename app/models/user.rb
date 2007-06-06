class User < ActiveRecord::Base
  has_many :comments
  has_many :stylesheets
  
  validates_uniqueness_of :openid_url, :on => :create
  validates_presence_of :openid_url
  validates_presence_of :nickname
  validates_inclusion_of :uses_full_name, :in => [true, false]
  
  def name
    if self.uses_full_name? and not self.fullname.blank?
      self.fullname
    else
      self.nickname
    end
  end
end
