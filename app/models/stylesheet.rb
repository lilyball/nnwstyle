class Stylesheet < ActiveRecord::Base
  belongs_to :user
  has_many :comments, :order => 'comments.created_at DESC'
  has_many :resources, :conditions => "resources.name != 'thumbnail'"
  has_one :thumbnail, :class_name => 'Resource', :conditions => "resources.name = 'thumbnail'"
  has_one :template, :class_name => 'Resource', :conditions => "resources.name = 'template.html'"
  has_one :css, :class_name => 'Resource', :conditions => "resources.name = 'stylesheet.css'"
  
  validates_presence_of :name
  validates_presence_of :description
  validates_presence_of :user_id
  validates_presence_of :version
  
  validates_numericality_of :version
  
  def parsed_template(locals)
    temp = template.data rescue default_template
    
    temp.gsub(/\[\[(\w+)\]\]/) do |match|
      locals.fetch($1.to_sym, match)
    end
  end
  
  def to_param
    "#{id}-#{name.gsub(/[^a-z1-9]+/i, '-').downcase}"
  end
  
  private
  def default_template
    <<-HTML
<div class="newsItemContainer">
  <div class="newsItemTitle"><strong>[[newsitem_title]]</strong></div>
  <div class="newsItemDescription">[[newsitem_description]]
    <p class="newsItemExtraLinks">[[newsitem_extralinks]]</p>
  </div>
  <div class="newsItemDateLine">[[newsitem_dateline]]</div>
</div>
    HTML
  end
end