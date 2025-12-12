# frozen_string_literal: true

require 'test_helper'
require 'stringio'

class PlanCopierTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "plan_copier_user_#{SecureRandom.hex(4)}@example.com",
      name: 'Plan Copier User',
      google_id: "plan-copier-#{SecureRandom.hex(8)}",
      is_anonymous: false
    )

    @farm = Farm.create!(
      user: @user,
      name: "Plan Copier Farm #{SecureRandom.hex(4)}",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: false
    )
  end

  test 'attachments are duplicated when copying a plan' do
    plan_year = Date.current.year
    planning_dates = CultivationPlan.calculate_public_planning_dates

    source_plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 1.0,
      status: 'pending',
      plan_type: 'public',
      plan_year: nil,
      plan_name: 'Attachment copy source',
      planning_start_date: planning_dates[:start_date],
      planning_end_date: planning_dates[:end_date]
    )

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('dummy pdf data'),
      filename: 'plan.pdf',
      content_type: 'application/pdf'
    )
    ActiveStorage::Attachment.create!(name: 'attachments', record: source_plan, blob: blob)

    result = PlanCopier.new(source_plan: source_plan, new_year: plan_year + 1, user: @user).call

    assert result.success?, result.errors.join(', ')
    new_plan = result.new_plan

    copied_attachments = ActiveStorage::Attachment.where(record: new_plan, name: 'attachments')
    assert_equal 1, copied_attachments.count, 'コピー先プランにも添付が複製されること'

    source_plan.destroy!
    assert_equal 1,
                 ActiveStorage::Attachment.where(record: new_plan, name: 'attachments').count,
                 '元プラン削除後もコピー先の添付が参照可能であること'
  end
end
