puts "データベースをクリーンアップ中..."
Comment.destroy_all
Article.destroy_all
Category.destroy_all
Tag.destroy_all
BlogSetting.destroy_all
User.destroy_all

puts "ユーザーを作成中..."

# 管理者ユーザー
admin = User.create!(
  username: "admin",
  email: "admin@example.com",
  password: "password",
  password_confirmation: "password",
  role: :admin,
  confirmed_at: Time.current
)

# 一般ユーザー1
alice = User.create!(
  username: "alice",
  email: "alice@example.com",
  password: "password",
  password_confirmation: "password",
  role: :user,
  confirmed_at: Time.current
)

# 一般ユーザー2
bob = User.create!(
  username: "bob",
  email: "bob@example.com",
  password: "password",
  password_confirmation: "password",
  role: :user,
  confirmed_at: Time.current
)

puts "ユーザー作成完了: #{User.count}名"

# ブログ設定を作成
[ admin, alice, bob ].each do |user|
  BlogSetting.create!(
    user: user,
    blog_title_ja: "#{user.username}のブログ",
    blog_title_en: "#{user.username}'s Blog",
    layout_style: "linear",
    theme_color: "default",
    show_hero_thumbnail: false
  )
end

puts "記事を作成中..."

# 各ユーザーに3記事ずつ作成
[ admin, alice, bob ].each do |user|
  3.times do |i|
    # 日本語記事（オリジナル）
    article_ja = Article.create!(
      user: user,
      title: "sample-title-#{i + 1}",
      content: "sample-content-#{i + 1}",
      locale: "ja",
      status: :published,
      published_at: Time.current - (i + 1).days
    )

    # 英語翻訳記事
    article_en = Article.create!(
      user: user,
      title: "sample-title-#{i + 1}-EN",
      content: "sample-content-#{i + 1}-EN (translation)",
      locale: "en",
      status: :published,
      published_at: Time.current - (i + 1).days,
      original_article: article_ja
    )

    # 各記事に1件コメントを追加
    Comment.create!(
      article: article_ja,
      author_name: "test-commenter",
      content: "this is a test comment",
      website: nil
    )

    Comment.create!(
      article: article_en,
      author_name: "test-commenter",
      content: "this is a test comment on EN article",
      website: nil
    )
  end
end

puts "記事作成完了: #{Article.count}件"
puts "コメント作成完了: #{Comment.count}件"

puts "\n" + "="*50
puts "Seedsデータ作成完了！"
puts "="*50
puts "\nログイン情報:"
puts "管理者: admin@example.com / password"
puts "Alice: alice@example.com / password"
puts "Bob: bob@example.com / password"
puts "\nアクセス先:"
puts "Admin: http://localhost:3000/u/admin/articles?locale=ja"
puts "Alice: http://localhost:3000/u/alice/articles?locale=ja"
puts "Bob: http://localhost:3000/u/bob/articles?locale=ja"
puts "="*50
