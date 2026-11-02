class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: { message: "est obligatoire" }, uniqueness: { message: "est déjà enregistré" }
  validates :p256dh, presence: { message: "est obligatoire" }
  validates :auth, presence: { message: "est obligatoire" }

  def deliver(title:, body:, path:)
    config = Rails.application.config.x.web_push
    if config.public_key.blank? || config.private_key.blank?
      Rails.logger.warn("[web_push] Clés VAPID absentes")
      return :transient
    end

    WebPush.payload_send(
      message: { title:, body:, path: }.to_json,
      endpoint:,
      p256dh:,
      auth:,
      vapid: {
        subject: config.subject,
        public_key: config.public_key,
        private_key: config.private_key
      },
      ttl: 24.hours.to_i
    )
    :sent
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
    destroy!
    :gone
  rescue WebPush::PayloadTooLarge => error
    Rails.logger.warn("[web_push] #{error.class}")
    :permanent
  rescue WebPush::TooManyRequests, WebPush::PushServiceError, WebPush::ResponseError,
         Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => error
    Rails.logger.warn("[web_push] #{error.class}")
    :transient
  end

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    endpoint: "L'adresse",
    p256dh: "La clé",
    auth: "Le secret"
  }.freeze
end
