require "test_helper"

class ContactTest < ActiveSupport::TestCase
  def build_contact(**attributes)
    Contact.new({ name: "テスト太郎", email: "test@example.com", subject: "件名", message: "本文" }.merge(attributes))
  end

  test "email は255文字までなら有効で、256文字だと無効になる" do
    domain = "@example.com"

    assert build_contact(email: "a" * (255 - domain.length) + domain).valid?

    contact = build_contact(email: "a" * (256 - domain.length) + domain)
    assert_not contact.valid?
    assert contact.errors[:email].any?
  end
end
