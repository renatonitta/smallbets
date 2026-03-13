require "test_helper"

class WeeklyDigestJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    Rails.application.routes.default_url_options[:host] = "localhost:3000"
    ActionMailer::Base.default_url_options[:host] = "localhost:3000"
    ActionMailer::Base.delivery_method = :test

    @account = accounts(:signal)
    @account.update!(email_digest_enabled: true)

    @user = users(:david)
    @user.subscribe("weekly_digest")

    @source_room = rooms(:pets)

    @rooms = 10.times.map do |i|
      room = Rooms::Open.create!(name: "Topic #{i}", source_room: @source_room, creator: @user)
      FeedCard.create!(room: room, title: "Topic #{i}", summary: "Summary #{i}", type: "automated", created_at: 2.days.ago)
      Message.create!(room: room, creator: @user, body: ActionText::Content.new("Message #{i}"), created_at: 2.days.ago)
      room
    end
  end

  test "sends digest to subscribed users" do
    assert_emails 1 do
      WeeklyDigestJob.new.perform
    end
  end

  test "creates email digest entries for each topic" do
    WeeklyDigestJob.new.perform

    assert_equal 10, EmailDigestEntry.count
    assert_equal Date.current, EmailDigestEntry.first.digest_date
    assert_equal (1..10).to_a, EmailDigestEntry.order(:position).pluck(:position)
  end

  test "skips when account digest is disabled" do
    @account.update!(email_digest_enabled: false)

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end

    assert_equal 0, EmailDigestEntry.count
  end

  test "skips when fewer than minimum topics" do
    FeedCard.where(room_id: @rooms.first(8).map(&:id)).destroy_all

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end

    assert_equal 0, EmailDigestEntry.count
  end

  test "does not send to unsubscribed users" do
    @user.unsubscribe("weekly_digest")

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end
  end

  test "excludes rooms already sent in previous digests" do
    EmailDigestEntry.create!(room: @rooms.first, digest_date: 1.week.ago, position: 1)

    WeeklyDigestJob.new.perform

    room_ids = EmailDigestEntry.where(digest_date: Date.current).pluck(:room_id)
    assert_not_includes room_ids, @rooms.first.id
  end

  test "excludes rooms marked as exclude_from_digest" do
    @rooms.first.update!(exclude_from_digest: true)

    WeeklyDigestJob.new.perform

    room_ids = EmailDigestEntry.where(digest_date: Date.current).pluck(:room_id)
    assert_not_includes room_ids, @rooms.first.id
  end

  test "does not include topics older than one week" do
    FeedCard.update_all(created_at: 2.weeks.ago)

    assert_no_emails do
      WeeklyDigestJob.new.perform
    end
  end

  test "groups topics by source room" do
    other_source = rooms(:hq)
    other_room = Rooms::Open.create!(name: "HQ Topic", source_room: other_source, creator: @user)
    FeedCard.create!(room: other_room, title: "HQ Topic", summary: "HQ Summary", type: "automated", created_at: 2.days.ago)
    Message.create!(room: other_room, creator: @user, body: ActionText::Content.new("HQ Message"), created_at: 2.days.ago)

    WeeklyDigestJob.new.perform
    email = ActionMailer::Base.deliveries.last

    html = email.html_part.body.to_s
    assert_includes html, "All Pets"
    assert_includes html, "HQ"

    pets_pos = html.index("All Pets")
    hq_pos = html.index("HQ")

    # Both source rooms appear, and topics from the same source room are grouped together
    # (all @rooms topics are under "All Pets", the new one under "HQ")
    assert pets_pos.present?
    assert hq_pos.present?

    # All 10 original topic links should appear between the "All Pets" header and "HQ" header,
    # confirming they're grouped under the same source room
    @rooms.each do |room|
      topic_pos = html.index(room.automated_feed_card.title)
      if pets_pos < hq_pos
        assert topic_pos > pets_pos && topic_pos < hq_pos, "Expected #{room.automated_feed_card.title} to be grouped under All Pets"
      else
        assert topic_pos > pets_pos, "Expected #{room.automated_feed_card.title} to be grouped under All Pets"
      end
    end
  end

  test "orders source room groups by message count" do
    other_source = rooms(:hq)

    # Create 5 topics under HQ with many messages to make it rank higher
    5.times do |i|
      room = Rooms::Open.create!(name: "HQ Topic #{i}", source_room: other_source, creator: @user)
      FeedCard.create!(room: room, title: "HQ Topic #{i}", summary: "Summary", type: "automated", created_at: 2.days.ago)
      20.times do |j|
        Message.create!(room: room, creator: @user, body: ActionText::Content.new("Msg #{j}"), created_at: 2.days.ago)
      end
    end

    # Also add more messages directly to HQ so it ranks higher in RoomStatsQuery
    50.times do |i|
      Message.create!(room: other_source, creator: @user, body: ActionText::Content.new("HQ direct #{i}"), created_at: 2.days.ago)
    end

    WeeklyDigestJob.new.perform
    email = ActionMailer::Base.deliveries.last
    html = email.html_part.body.to_s

    hq_pos = html.index("HQ")
    pets_pos = html.index("All Pets")

    assert hq_pos < pets_pos, "Expected HQ (more messages) to appear before All Pets"
  end
end
