class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers
  include ActionController::Cookies
end
