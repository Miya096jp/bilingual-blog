require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @valid_params = {
      contact: {
        name: "テスト太郎",
        email: "test@example.com",
        subject: "テスト件名",
        message: "テストメッセージ"
      }
    }
  end

  test "通常の入力(日本語)でContactが作成され、メールが送信される" do
    assert_difference("Contact.count", 1) do
      assert_emails 1 do
        post contacts_path(locale: "ja"), params: @valid_params
      end
    end

    assert_redirected_to new_contact_path(locale: "ja")
    assert_equal "お問い合わせを送信しました。ありがとうございます。", flash[:notice]
  end

  test "通常の入力(英語)でContactが作成され、メールが送信される" do
    assert_difference("Contact.count", 1) do
      assert_emails 1 do
        post contacts_path(locale: "en"), params: @valid_params
      end
    end

    assert_redirected_to new_contact_path(locale: "en")
    assert_equal "お問い合わせを送信しました。ありがとうございます。", flash[:notice]
  end

  test "ハニーポット欄に値が入っている場合、Contactが作成されずメールも送信されないが、成功時と同じ表示になる" do
    params = @valid_params.deep_merge(contact: { website: "https://spam.example.com" })

    assert_no_difference("Contact.count") do
      assert_emails 0 do
        post contacts_path(locale: "ja"), params: params
      end
    end

    assert_redirected_to new_contact_path(locale: "ja")
    assert_equal "お問い合わせを送信しました。ありがとうございます。", flash[:notice]
  end

  test "ハニーポット欄が空の場合は通常どおり作成される" do
    params = @valid_params.deep_merge(contact: { website: "" })

    assert_difference("Contact.count", 1) do
      post contacts_path(locale: "ja"), params: params
    end

    assert_redirected_to new_contact_path(locale: "ja")
  end
end
