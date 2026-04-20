class Api::V1::SessionsController < Devise::SessionsController
  include ActionController::Cookies
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    # Devise-JWT issues the access token
    access_token = request.env["warden-jwt_auth.token"]

    # Generate refresh token and store in database
    refresh_token = SecureRandom.hex(32)
    resource.update(
      refresh_token: refresh_token,
      refresh_token_expires_at: 7.days.from_now
    )

    # Set HttpOnly cookie — JavaScript cannot read this
    cookies.signed[:refresh_token] = {
      value: refresh_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      expires: 7.days.from_now
    }

    render json: {
      status: { code: 200, message: "Logged in successfully." },
      data: UserSerializer.new(resource).serializable_hash[:data][:attributes],
      access_token: access_token
    }, status: :ok
  end

  def respond_to_on_destroy(*args)
    if current_user
      # Clear refresh token from database
      current_user.update(
        refresh_token: nil,
        refresh_token_expires_at: nil
      )
      # Delete HttpOnly cookie
      cookies.delete(:refresh_token)

      render json: {
        status: { code: 200, message: "Logged out successfully." }
      }, status: :ok
    else
      render json: {
        status: { code: 401, message: "Couldn't find an active session." }
      }, status: :unauthorized
    end
  end
end
