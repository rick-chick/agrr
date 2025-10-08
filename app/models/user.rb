# frozen_string_literal: true

class User < ApplicationRecord
  # Associations
  has_many :sessions, dependent: :destroy
  has_many :farms, dependent: :destroy
  has_many :fields, dependent: :destroy

  # Validations
  validates :email, presence: true, 
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :name, presence: true, length: { maximum: 50 }
  validates :google_id, presence: true, uniqueness: true
  validates :avatar_url, format: { with: /\A(#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}|[a-zA-Z0-9_-]+\.svg)\z/, 
                                   message: "must be a valid URL or SVG filename" },
                         allow_blank: true

  # Normalize email before validation
  before_validation :normalize_email

  # Admin methods
  def admin?
    admin
  end

  def make_admin!
    update!(admin: true)
  end

  def remove_admin!
    update!(admin: false)
  end

  # Class method to find or create user from OmniAuth hash
  def self.from_omniauth(auth_hash)
    # Validate required fields from auth hash
    raise ActiveRecord::RecordInvalid.new(User.new) unless auth_hash['uid'].present?
    raise ActiveRecord::RecordInvalid.new(User.new) unless auth_hash.dig('info', 'email').present?
    raise ActiveRecord::RecordInvalid.new(User.new) unless auth_hash.dig('info', 'name').present?

    # Find existing user by google_id
    user = find_by(google_id: auth_hash['uid'])
    
    # Process avatar URL to extract filename if it's a local asset
    avatar_url = process_avatar_url(auth_hash.dig('info', 'image'))
    
    if user
      # Update existing user with latest info
      user.update!(
        email: auth_hash.dig('info', 'email'),
        name: auth_hash.dig('info', 'name'),
        avatar_url: avatar_url
      )
      user
    else
      # Create new user
      create!(
        email: auth_hash.dig('info', 'email'),
        name: auth_hash.dig('info', 'name'),
        google_id: auth_hash['uid'],
        avatar_url: avatar_url
      )
    end
  end

  # Process avatar URL to extract filename for local assets
  def self.process_avatar_url(url)
    return nil if url.blank?
    
    # If it's a local asset path like '/assets/dev-avatar.svg'
    # extract just the filename 'dev-avatar.svg'
    if url.start_with?('/assets/')
      url.sub(%r{\A/assets/}, '')
    else
      # External URL (like Google profile image), keep as-is
      url
    end
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end
end
