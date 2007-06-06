require 'erb'
require 'yaml'
require 'active_support/core_ext'

module FixtureSupport
  def self.bindata(file)
    %Q{!binary |\n#{' ' * 8}#{[File.read("#{RAILS_ROOT}/test/fixtures/resources/#{file}")].pack("m").gsub(/\n/, ' ' * 8)}}
  end
  
  @entities = {}
  
  def self.load_fixture(klass)
    klass.transaction do
      erb = ERB.new(File.read("#{RAILS_ROOT}/test/fixtures/#{klass.to_s.downcase.pluralize}.yml"))
      items = YAML.load(erb.result(binding))
      items.each do |(key,value)|
        @entities[key] = klass.create! value
      end
    end
  end
  
  def self.method_missing(name)
    @entities.fetch(name.id2name) rescue super
  end
end

def fixtures(*args)
  begin
    args.each do |klass|
      FixtureSupport.load_fixture(klass)
    end
  rescue
    User.delete_all
    Stylesheet.delete_all
    Resource.delete_all
    Comment.delete_all
    raise
  end
end

class CreateTestData < ActiveRecord::Migration
  def self.up
    fixtures User, Stylesheet, Resource, Comment
  end

  def self.down
    User.delete_all
    Stylesheet.delete_all
    Resource.delete_all
    Comment.delete_all
  end
end
