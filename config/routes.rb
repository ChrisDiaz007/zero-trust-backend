Rails.application.routes.draw do
  devise_for :users, path: "", path_names: {
    sign_in: "api/v1/auth/login",
    sign_out: "api/v1/auth/logout",
    registration: "api/v1/auth/signup"
  },
  controllers: {
    sessions: "api/v1/sessions",
    registrations: "api/v1/registrations"
  }
end
