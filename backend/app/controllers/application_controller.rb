class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Authentication

  before_action :require_json_for_mutations

  private
    def require_json_for_mutations
      return if request.get? || request.head? || request.delete? || request.options?
      return if request.content_mime_type == Mime[:json]

      render json: { errors: [ "Le contenu doit être du JSON" ] }, status: :unsupported_media_type
    end
end
