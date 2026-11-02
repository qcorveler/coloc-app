module Api
  module Colocs
    class RemindersController < ApplicationController
      include ColocScoped

      def create
        event.event_reminders.find_or_create_by!(user: Current.user, source: "subscribed")
        head :no_content
      end

      def destroy
        event.event_reminders.where(user: Current.user, source: "subscribed").delete_all
        head :no_content
      end

      private
        def event
          @event ||= @coloc.events.roots.find(params[:event_id])
        end
    end
  end
end
