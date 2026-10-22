module ColocScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_member_coloc
  end

  private
    def set_member_coloc
      @coloc = Coloc.find(params[:coloc_id] || params[:id])
      return if @coloc.memberships.exists?(user: Current.user)

      render json: { error: "Accès refusé" }, status: :forbidden
    end
end
