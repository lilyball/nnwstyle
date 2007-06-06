require "pathname"
require "cgi"

# load the openid library
begin
  require "rubygems"
  gem "ruby-openid", ">= 1.0.2"
rescue LoadError
end

require "openid"

class UserController < ApplicationController

  verify :only => :edit,
         :session => :user_id,
         :add_flash => { :note => "You need to be logged in to edit your profile" },
         :redirect => '/'

  def show
    @user = User.find(params[:id])
  end

  def edit
    @user = user
    if request.post?
      # we have to check individual parameters because half of the User fields
      # should not be allowed to change here
      input = params[:user]
      @user.uses_full_name = input[:uses_full_name] unless input[:uses_full_name].blank?
      @user.homepage = input[:homepage] unless input[:homepage].blank?
      @user.save
    end
  end

  # Login stuff

  # process the login request, disover the openid server, and
  # then redirect.
  def login
    openid_url = params[:openid_url]

    session[:redirect] = nil if request.get?
    session[:redirect] = params[:redirect] unless params[:redirect].blank?

    if request.post?
      if openid_url.blank?
        flash[:notice] = "Login can't be blank."
        return
      end
      
      request = consumer.begin(openid_url)

      case request.status
      when OpenID::SUCCESS
        request.add_extension_arg('sreg', 'required', 'nickname')
        request.add_extension_arg('sreg', 'optional', 'fullname')
        
        return_to = url_for(:action=> 'complete')
        trust_root = url_for(:controller=>'')

        url = request.redirect_url(trust_root, return_to)
        redirect_to(url)
        return

      when OpenID::FAILURE
        escaped_url = CGI::escape(openid_url)
        flash[:notice] = "Could not find OpenID server for #{escaped_url}"
      else
        flash[:notice] = "An unknown error occured."
      end
    end

  end

  # handle the openid server response
  def complete
    response = consumer.complete(params)

    case response.status
    when OpenID::SUCCESS
      @user = User.find_or_initialize_by_openid_url(URI.parse(response.identity_url).host)
      @user.nickname = response.extension_response('sreg')['nickname']
      @user.fullname = response.extension_response('sreg')['fullname']
      @user.uses_full_name = false if @user.new_record?

      @user.save!

      # storing both the openid_url and user id in the session for for quick
      # access to both bits of information.  Change as needed.
      session[:user_id] = @user.id
      flash[:notice] = "Logged in as #{CGI::escape(@user.name)}"

      if session[:redirect].blank?
        redirect_to :action => "welcome"
      else
        redir = session[:redirect]
        session[:redirect] = nil
        redirect_to redir
      end
      return

    when OpenID::FAILURE
      if response.identity_url
        flash[:notice] = "Verification of #{CGI::escape(response.identity_url)} failed."

      else
        flash[:notice] = 'Verification failed.'
      end

    when OpenID::CANCEL
      flash[:notice] = 'Verification cancelled.'

    else
      flash[:notice] = 'Unknown response from OpenID server.'
    end

    redirect_to :action => 'login'
  end

  def logout
    session[:user_id] = nil
    
    redirect_to :back
  end

  def welcome
  end

  private

  # Get the OpenID::Consumer object.
  def consumer
    # create the OpenID store for storing associations and nonces,
    # putting it in your app's db directory
    store_dir = Pathname.new(RAILS_ROOT).join('db').join('openid-store')
    store = OpenID::FilesystemStore.new(store_dir)

    return OpenID::Consumer.new(session, store)
  end
end
