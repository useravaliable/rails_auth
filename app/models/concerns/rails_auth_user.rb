##
# include this module to your User model
#   class User < ApplicationRecord
#     include RailsAuthUser
#   end
module RailsAuthUser
  extend ActiveSupport::Concern

  included do
    include ActiveModel::SecurePassword
    has_secure_password validations: false

    attribute :locale, :string, default: I18n.default_locale
    attribute :timezone, :string

    validates :email, uniqueness: true, if: -> { email.present? && email_changed? }
    validates :mobile, uniqueness: true, if: -> { mobile.present? && mobile_changed? }
    validates :password, confirmation: true, length: { in: 6..72 }, allow_blank: true

    has_one :unlock_token, -> { valid }
    has_many :unlock_tokens

    has_one :reset_token, -> { valid }
    has_many :reset_tokens

    has_many :access_tokens
    has_many :verify_tokens, autosave: true, dependent: :delete_all
    has_many :oauth_users, dependent: :nullify
    has_many :accounts, dependent: :nullify

    has_one_attached :avatar

    before_save :invalid_access_token, if: -> { password_digest_changed? }
    before_save :sync_to_accounts, if: -> { email_changed? || mobile_changed? }
  end

  def reset_token
    if super
      super
    else
      VerifyToken.transaction do
        self.reset_tokens.delete_all
        create_reset_token
      end
    end
  end

  def unlock_token
    if super
      super
    else
      VerifyToken.transaction do
        self.unlock_tokens.delete_all
        create_unlock_token
      end
    end
  end

  def join(params = {})
    self.assign_attributes params.slice(
      :name,
      :email,
      :mobile,
      :password,
      :password_confirmation
    )
    save
  end

  ##
  # pass login params to this method;
  def can_login?(params)
    if verified_status?
      return false
    end

    if password_digest? && params[:password].present?
      if authenticate(params[:password])
        self
      else
        errors.add :base, :wrong_name_or_password
        return false
      end
    else
      errors.add :base, :token_blank
      false
    end
  end

  def verified_status?
    if self.disabled?
      errors.add :base, :account_disable
      true
    else
      false
    end
  end

  def avatar_url
    avatar.service_url if avatar.attachment.present?
  end

  def valid_providers
    OauthUser.options_i18n(:provider).values.map(&:to_s) - oauth_providers
  end

  def invalid_access_token
    self.access_tokens.delete_all
  end

  def generate_auth_token(**options)
    JwtHelper.generate_jwt_token(id, password_digest, options)
  end

  def oauth_providers
    oauth_users.pluck(:provider).compact
  end

  def sync_to_accounts
    if email_changed?
      sync_to_email_accounts
    end
    if mobile_changed?
      sync_to_mobile_accounts
    end
  end

  def sync_to_accounts!
    sync_to_email_accounts
    sync_to_mobile_accounts
    self.save
  end

  def sync_to_email_accounts
    if email.present?
      ac = accounts.find_or_initialize_by(identity: email)
    end
    accounts.where(identity: email_was).delete_all
  end

  def sync_to_mobile_accounts
    if mobile.present?
      ac = accounts.find_or_initialize_by(identity: mobile)
    end
    accounts.where(identity: mobile_was).delete_all
  end

end

