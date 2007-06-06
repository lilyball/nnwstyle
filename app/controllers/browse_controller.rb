require 'zlib'
require 'archive/tar/minitar'
require 'plist'
require 'mime/types'
require 'zip/zip'

class BrowseController < ApplicationController
  before_filter :validate_id, :except => :comment

  verify :only => :new,
         :session => :user_id,
         :add_flash => { :note => "Please log in to upload stylesheets" },
         :redirect_to => '/'

  def index
    @stylesheet_pages, @stylesheets = paginate :stylesheets, :per_page => 10, :order => 'version_updated_at DESC', :include => :user
  end

  def list
    @stylesheet_pages, @stylesheets = paginate :stylesheets, :per_page => 10, :order => 'name'
  end

  def show
    @stylesheet = Stylesheet.find(params[:id])
    if request.post?
      if user.blank?
        flash[:note] = "You must log in to comment"
      else
        @comment = @stylesheet.comments.build(params[:comment])
        @comment.user = user
        @comment.version = @stylesheet.version
        if @comment.save
          @comment = Comment.new
        else
          @stylesheet.comments.delete @comment
        end
      end
    else
      @comment = Comment.new
    end
  end

  def new
    if request.post?
      file = params[:stylesheet][:file]
      params[:stylesheet].delete :file
      @stylesheet = Stylesheet.new(params[:stylesheet])
      @stylesheet.user = user
      @stylesheet.version_updated_at = Time.now
      @stylesheet.errors.add_on_empty :file
      @stylesheet.valid? # populate errors
      @stylesheet.errors.add_to_base "Uploaded file is required" if file.blank?
      decode_resources(file, @stylesheet) # this will modify errors too
      if @stylesheet.errors.empty?
        @stylesheet.save_with_validation(false)
        redirect_to :action => :show, :id => @stylesheet.id
      end
    else
      @stylesheet = Stylesheet.new
    end
  end

  def edit
    @stylesheet = Stylesheet.find(params[:id])
    if request.post?
      file = params[:stylesheet][:file]
      params[:stylesheet].delete :file
      @stylesheet.version_updated_at = Time.now if params[:stylesheet][:version].to_f > @stylesheet.version.to_f
      @stylesheet.attributes = @stylesheet.attributes.merge(params[:stylesheet])
      if @stylesheet.valid?
        # now handle resources
        if file.blank? or decode_resources(file, @stylesheet)
          @stylesheet.save_with_validation(false)
          redirect_to :action => :show
        end
      end
    end
  end

  def resource
    @resource = Resource.find_by_name_and_stylesheet_id(params[:name], params[:id].to_i)
    send_resource @resource
  end

  def preview
    @stylesheet = Stylesheet.find(params[:id])
    render :layout => 'preview', :text => @stylesheet.parsed_template(
      :newsitem_title => '<a href="#">Lorem Ipsum</a>',
      :newsitem_description => <<-HTML,
<p>Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Vestibulum volutpat tellus sed felis.
Sed nisl libero, iaculis sit amet, ornare ut, semper a, sem. Mauris varius. Etiam fermentum
dolor volutpat erat. Nunc vitae augue nec mauris tincidunt imperdiet. Proin eu diam dapibus est
vestibulum suscipit. Proin mattis.</p>

<p>Sed lectus. Sed fringilla sem quis ligula. Etiam enim. Fusce porta luctus erat. Donec in libero.
Morbi pulvinar accumsan leo. Cras accumsan mi. Curabitur vehicula dictum elit. Pellentesque
vitae nulla vitae ligula euismod semper.</p>
      HTML
      :newsitem_extralinks => '',
      :newsitem_dateline => <<-HTML
<span class="newsItemSource"><a href="#">Lorem Ipsum</a></span>
<span class="newsItemDate">#{Time.now.strftime("%m/%d/%y %I:%M %p").gsub(%r{([/ ])0}, '\1')}</span>
<span class="newsItemCreator">Joe Author</span>
<span class="newsItemSubject">Uncategorized</span>
<span class="newsItemCommentsLink"><a href="#">Comments</a></span>
      HTML
    )
  end

  def download
    @stylesheet = Stylesheet.find(params[:id])
    
    begin
      buffer = StringIO.new("")
      tgz = Zlib::GzipWriter.new(buffer)
      tar = Archive::Tar::Minitar::Writer.new(tgz)
      basedir = "#{@stylesheet.name}.nnwstyle"
      @stylesheet.resources.each do |resource|
        path = File.join(basedir, resource.name)
        tar.add_file_simple(path, :size => resource.data.size,
                                  :mode => 0644,
                                  :mtime => resource.updated_at.to_i) do |io,opts|
          io.write resource.data
        end
      end
      # add the Info.plist file
      info = {:CreatorHomePage => @stylesheet.user.homepage || "",
              :CreatorName => @stylesheet.user.name,
              :Version => @stylesheet.version}.to_plist
      tar.add_file_simple(File.join(basedir, "Info.plist"),
                          :size => info.size,
                          :mode => 0644,
                          :mtime => @stylesheet.version_updated_at.to_i) do |io,opts|
        io.write info
      end
    ensure
      tar.close
      tgz.close
    end
    send_data buffer.string, :filename => "#{@stylesheet.name}.tgz", :type => "application/x-gzip",
                      :disposition => 'attachment'
  end

  private

  def send_resource(resource)
    if resource.nil?
      render :text => '', :status => 404
    else
      minTime = Time.rfc2822(request.env["HTTP_IF_MODIFIED_SINCE"]) rescue nil
      if minTime and resource.updated_at <= minTime
        # use cached version
        render :text => '', :status => 304
      else
        # send image
        response.headers['Last-Modified'] = resource.updated_at.httpdate
        mime = resource.mimeType.blank? ? resource.mimeType : "application/octet-stream"
        send_data resource.data, :type => mime, :disposition => 'inline'
      end
    end
  end

  def decode_resources(file, stylesheet)
    tgz = nil
    case file.content_type.strip
    when "application/x-gzip"
      tgz = Zlib::GzipReader.new(file)
      tar = Archive::Tar::Minitar::Reader.new(tgz)
    when "application/x-tar"
      tar = Archive::Tar::Minitar::Reader.new(file)
    when "application/zip", "application/x-zip"
      # we need to write out to a tempfile since ruby-zip can't handle reading from IO streams
      tgz = Tempfile.new('nnwstyle_zip')
      tgz.write file.read
      tgz.close
      tar = Zip::ZipFileSham.new(tgz.path)
    else
      stylesheet.errors.add_to_base "Uploaded file is not a known archive format"
      return false
    end
    found_css = false
    resources = []
    tar.each_entry do |entry|
      if entry.file? && entry.full_name != "Info.plist"
        res = Resource.new
        res.name = File.basename(entry.full_name)
        found_css = true if res.name == "stylesheet.css"
        res.data = entry.read
        res.mimeType = MIME::Types.type_for(File.extname(res.name)).to_s
        resources << res
      end
    end
    tar.close
    tgz.close unless tgz.nil?
    if found_css
      stylesheet.resources.replace(resources)
      true
    else
      stylesheet.errors.add_to_base "Uploaded archive does not have a stylesheet.css file"
      false
    end
  end
  
  def validate_id
    if request.get?
      id = params[:id]
      unless id.nil?
        stylesheet = Stylesheet.find(params[:id])
        if stylesheet.to_param != id
          headers['Status'] = '301 Moved Permanently'
          redirect_to params.merge(:id => stylesheet)
        end
      end
    end
  end
end

# This here is to pretend to be a Minitar object for API compatibility purposes
module Zip
  class ZipFileSham
    def initialize(path)
      @path = path
    end
    
    def each_entry
      ZipFile.foreach(@path) do |entry|
        yield ZipEntryWrapper.new(entry)
      end
    end
    
    def close
      # noop
    end
  end

  class ZipEntryWrapper
    def initialize(entry)
      @entry = entry
    end
  
    def file?
      @entry.file?
    end
  
    def full_name
      @entry.name
    end
  
    def read
      @entry.get_input_stream.read
    end
  end
end