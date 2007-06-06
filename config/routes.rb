ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"
  
  map.connect '', :controller => 'browse'
  
  map.with_options :controller => 'browse' do |browse|
    browse.connect '/browse', :action => 'index'
    browse.connect '/browse/page/:page', :action => 'index'
    browse.show '/browse/show/:id', :action => 'show'
    browse.thumbnail '/browse/thumbnail/:id', :action => 'resource', :name => 'thumbnail'
    browse.named_route 'resource', '/browse/resource/:id/*name', :action => 'resource'
  end

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
