module Api
  class ColocsController < ApplicationController
    include ColocScoped

    skip_before_action :set_member_coloc, only: [ :index, :create ]

    def index
      colocs = Current.user.colocs.with_attached_photo.order(created_at: :desc)
      render json: { colocs: colocs.map { |coloc| coloc.summary(host: request.base_url) } }
    end

    def show
      render json: { coloc: @coloc.detail(host: request.base_url) }
    end

    def create
      coloc = Coloc.new(coloc_params)
      unless coloc.save
        return render json: { errors: coloc.errors.full_messages }, status: :unprocessable_entity
      end

      unless coloc.add_member(Current.user)
        return render json: { errors: coloc.errors.full_messages }, status: :unprocessable_entity
      end

      render json: { coloc: coloc.reload.detail(host: request.base_url) }, status: :created
    end

    def update
      @coloc.photo.purge if remove_photo? && params[:photo].blank?

      if @coloc.update(coloc_params)
        render json: { coloc: @coloc.reload.detail(host: request.base_url) }
      else
        render json: { errors: @coloc.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private
      def coloc_params
        params.permit(:name, :address, :description, :photo)
      end

      def remove_photo?
        ActiveModel::Type::Boolean.new.cast(params[:remove_photo])
      end
  end
end
