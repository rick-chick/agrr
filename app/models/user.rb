# frozen_string_literal: true

class User < ApplicationRecord
  # Associations
  has_many :sessions, dependent: :destroy

  # Validations
  validates :email, presence: true, 
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :name, presence: true, length: { maximum: 50 }
  validates :google_id, presence: true, uniqueness: true
  validates :avatar_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), 
                                   message: "must be a valid URL" },
                         allow_blank: true

  # Normalize email before validation
  before_validation :normalize_email

  # Class method to find or create user from OmniAuth hash
  def self.from_omniauth(auth_hash)
    # Validate required fields from auth hash
    raise ActiveRecord::RecordInvalid.new(User.new) unless auth_hash['uid'].present?
    raise ActiveRecord::RecordInvalid.new(User.new) unless auth_hash.dig('info', 'email').present?
    raise ActiveRecord::RecordInvalid.new(User.new) unless auth_hash.dig('info', 'name').present?

    # Find existing user by google_id
    user = find_by(google_id: auth_hash['uid'])
    
    if user
      # Update existing user with latest info
      user.update!(
        email: auth_hash.dig('info', 'email'),
        name: auth_hash.dig('info', 'name'),
        avatar_url: auth_hash.dig('info', 'image')
      )
      user
    else
      # Create new user
      create!(
        email: auth_hash.dig('info', 'email'),
        name: auth_hash.dig('info', 'name'),
        google_id: auth_hash['uid'],
        avatar_url: auth_hash.dig('info', 'image')
      )
    end
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end
end
