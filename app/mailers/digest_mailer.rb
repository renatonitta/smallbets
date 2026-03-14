class DigestMailer < ApplicationMailer
  helper RoomsHelper
  helper_method :room_icon

  def weekly(user, grouped_rooms)
    @user = user
    @grouped_rooms = grouped_rooms
    @digest_date = Date.current

    mail(to: @user.email_address, subject: "This week in Small Bets - #{@digest_date.strftime("%b %-d, %Y")}")
  end

  private

  def room_icon(name)
    return nil if name.blank?

    emoji_pattern = /\A((?:[\p{Emoji_Presentation}\p{Extended_Pictographic}]|[\p{Emoji}]\uFE0F)(?:\u200D(?:[\p{Emoji_Presentation}\p{Extended_Pictographic}]|[\p{Emoji}]\uFE0F?))*)/
    match = name.match(emoji_pattern)
    match ? match[1] : name.strip[0]&.upcase
  end
end
