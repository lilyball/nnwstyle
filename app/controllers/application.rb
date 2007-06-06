# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require_dependency "openid_login_system"

class ApplicationController < ActionController::Base
  include OpenidLoginSystem

  layout 'default'

  private

  # get the logged in user object
  def user
    return nil if session[:user_id].nil?
    @cached_user ||= User.find(session[:user_id])
  end

  helper_method :user
end
