class Api::V1::BaseController < ApplicationController
  # Protect all routes, requires valid JWT token
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def not_found(error)
    render json: {
      status: { code: 404, message: error.message }
    }, status: :not_found
  end

  def bad_request(error)
    render json: {
      status: { code: 400, message: error.message }
    }, status: :bad_request
  end
end
