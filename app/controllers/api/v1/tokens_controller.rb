class Api::V1::TokensController < Api::V1::BaseController
  include ActionController::Cookies

  skip_before_action :authenticate_user!, only: [ :refresh_token ]

  def refresh_token
    # Read refresh token from HttpOnly cookie
    current_refresh = cookies.signed[:refresh_token]

    # No cookie present
    if current_refresh.blank?
      return render json: {
        status: { code: 401, message: "Missing refresh token." }
      }, status: :unauthorized
    end

    # Find user by refresh token
    user = User.find_by(refresh_token: current_refresh)

    # Invalid or expired refresh token
    unless user && user.refresh_token_expires_at&.future?
      return render json: {
        status: { code: 401, message: "Invalid or expired refresh token." }
      }, status: :unauthorized
    end

    # Rotate refresh token — invalidates old one
    new_refresh = SecureRandom.hex(32)
    new_expiry  = 7.days.from_now
    user.update!(
      refresh_token: new_refresh,
      refresh_token_expires_at: new_expiry
    )

    # Set new HttpOnly cookie
    cookies.signed[:refresh_token] = {
      value: new_refresh,
      httponly: true,
      secure: Rails.env.production?,
      same_site: Rails.env.production? ? :none : :strict,
      expires: new_expiry
    }

    # Issue a new access token
    new_access_token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first

    render json: {
      status: { code: 200, message: "Token refreshed successfully." },
      access_token: new_access_token
    }, status: :ok
  end
end
