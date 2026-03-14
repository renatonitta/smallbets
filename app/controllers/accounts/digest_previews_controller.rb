class Accounts::DigestPreviewsController < ApplicationController
  before_action :ensure_can_administer

  MAX_TOPICS = 50
  MIN_TOPICS = 3

  def create
    user = User.find_by(email_address: params[:email])

    unless user
      redirect_to edit_account_url, alert: "No user found with that email."
      return
    end

    rooms = WeeklyDigestJob.fetch_top_rooms(limit: MAX_TOPICS, since: 1.week.ago)

    if rooms.length < MIN_TOPICS
      redirect_to edit_account_url, alert: "Only #{rooms.length} topics found (minimum: #{MIN_TOPICS}). Try a longer time range."
      return
    end

    grouped = WeeklyDigestJob.group_by_source_room(rooms)

    DigestMailer.weekly(user, grouped).deliver_now
    redirect_to edit_account_url, notice: "Digest preview sent to #{user.email_address}."
  end
end
