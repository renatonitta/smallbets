class StatsService
  # Get top posters for a specific day
  def self.top_posters_for_day(day, limit = 10)
    # Explicitly parse the date in UTC timezone
    day_start = Time.parse(day + " UTC").beginning_of_day
    day_end = day_start.end_of_day

    # Use a more direct query with explicit date formatting to match SQLite's format
    day_formatted = day_start.strftime("%Y-%m-%d")

    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins("INNER JOIN messages ON messages.creator_id = users.id AND messages.active = true
                INNER JOIN rooms ON messages.room_id = rooms.id AND rooms.type != 'Rooms::Direct'")
        .where("strftime('%Y-%m-%d', messages.created_at) = ?", day_formatted)
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end

  # Get top posters for a specific month
  def self.top_posters_for_month(month, limit = 10)
    year, month_num = month.split("-")
    # Explicitly use UTC timezone
    month_start = Time.new(year.to_i, month_num.to_i, 1, 0, 0, 0, "+00:00").beginning_of_month
    month_end = month_start.end_of_month

    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins(messages: :room)
        .where("rooms.type != ? AND messages.created_at >= ? AND messages.created_at <= ? AND messages.active = true",
              "Rooms::Direct", month_start, month_end)
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end

  # Get top posters for a specific year
  def self.top_posters_for_year(year, limit = 10)
    # Explicitly use UTC timezone
    year_start = Time.new(year.to_i, 1, 1, 0, 0, 0, "+00:00").beginning_of_year
    year_end = year_start.end_of_year

    User.select("users.id, users.name, COUNT(messages.id) AS message_count, COALESCE(users.membership_started_at, users.created_at) as joined_at")
        .joins(messages: :room)
        .where("rooms.type != ? AND messages.created_at >= ? AND messages.created_at <= ? AND messages.active = true",
              "Rooms::Direct", year_start, year_end)
        .where("users.active = true AND users.suspended_at IS NULL")
        .group("users.id, users.name, users.membership_started_at, users.created_at")
        .order("message_count DESC, joined_at ASC, users.id ASC")
        .limit(limit)
  end
end
