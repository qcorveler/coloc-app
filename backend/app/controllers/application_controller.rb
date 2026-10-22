class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ActiveStorage::SetCurrent
  include Authentication

  before_action :require_json_for_mutations

  private
    def require_json_for_mutations
      return if request.get? || request.head? || request.delete? || request.options?
      return if request.content_mime_type == Mime[:json]
      return if multipart_with_requested_header?

      render json: { errors: [ "Le contenu doit être du JSON" ] }, status: :unsupported_media_type
    end

    def multipart_with_requested_header?
      request.content_mime_type == Mime[:multipart_form] &&
        request.headers["X-Requested-With"] == "XMLHttpRequest"
    end
end
