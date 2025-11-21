puts "Starting to create seed data..."

Comment.destroy_all
Article.destroy_all
Category.destroy_all
User.destroy_all

puts "Creating users..."

# 管理者アカウント
admin_user = User.find_or_initialize_by(email: "admin@example.com")
admin_user.password = "password"
admin_user.password_confirmation = "password"
admin_user.role = :admin
admin_user.username = "admin"
admin_user.save!

# テスト用ユーザー
test_user = User.find_or_initialize_by(email: "test@example.com")
test_user.password = "password"
test_user.password_confirmation = "password"
test_user.role = :user
test_user.username = "testuser"
test_user.save!

puts "Creating categories..."

# カテゴリ作成（admin_userに紐付け）
ja_programming = admin_user.categories.create!(name: 'プログラミング', locale: 'ja', description: 'プログラミング関連の記事')
ja_daily = admin_user.categories.create!(name: '日常', locale: 'ja', description: '日常の出来事について')
ja_tech = admin_user.categories.create!(name: '技術Tips', locale: 'ja', description: '開発で役立つ技術情報')

en_programming = admin_user.categories.create!(name: 'Programming', locale: 'en', description: 'Articles about programming')
en_daily = admin_user.categories.create!(name: 'Daily Life', locale: 'en', description: 'About daily life')
en_tech = admin_user.categories.create!(name: 'Tech Tips', locale: 'en', description: 'Useful technical information')

categories_ja = [ ja_programming, ja_daily, ja_tech ]
categories_en = [ en_programming, en_daily, en_tech ]

puts "Creating articles..."

30.times do |i|
  category = categories_ja.sample  # ランダムにカテゴリを選択

  ja_article = admin_user.articles.create!(  # admin_user.articles.create!に変更
    title: "日本語記事#{i + 1}",
    locale: 'ja',
    content: <<~CONTENT,
      # プログラミング学習第#{i + 1}回
#{'      '}
      第#{i + 1}回目の**日本語記事**です。
#{'      '}
      ## 学習内容
      - Ruby基礎
      - Rails入門
      - `puts "Hello World"`

```ruby
      def hello
        puts "Hello, World! - #{i + 1}"
      end
```
#{'      '}
      **カテゴリ**: #{category.name}
    CONTENT
    status: :published,
    published_at: (30 - i).days.ago + rand(24).hours,
    category: category,
    tag_list: [ 'プログラミング', 'Ruby', 'Rails', '初心者', '学習' ].sample(rand(2..4)).join(', ')
  )

  # 偶数番号の記事には英語翻訳を追加
  if i.even?
    en_category = categories_en.sample

    admin_user.articles.create!(  # admin_user.articles.create!に変更
      title: "English Article #{i + 1}",
      locale: 'en',
      content: <<~CONTENT,
        # Programming Study Part #{i + 1}
#{'        '}
        This is the #{i + 1}th **English article**.
#{'        '}
        ## Learning Content
        - Ruby Basics
        - Rails Introduction
        - `puts "Hello World"`

```ruby
        def hello
          puts "Hello, World! - #{i + 1}"
        end
```
#{'        '}
        **Category**: #{en_category.name}
      CONTENT
      status: :published,
      published_at: ja_article.published_at,
      original_article: ja_article,
      category: en_category,
      tag_list: [ 'Programming', 'Ruby', 'Rails', 'Beginner', 'Learning' ].sample(rand(2..4)).join(', ')
    )
  end
end

# 下書き記事
3.times do |i|
  admin_user.articles.create!(  # admin_user.articles.create!に変更
    title: "下書き記事 #{i + 1}",
    locale: "ja",
    content: "この記事は準備中です...",
    status: :draft,
    category: categories_ja.sample
  )
end

# コメントのseed（新規追加）
puts 'Creating comment seed data...'

# 日本語記事へのコメント
Article.where(locale: 'ja', status: :published).each_with_index do |article, index|
  rand(1..2).times do |i|
    Comment.find_or_create_by(
      article: article,
      author_name: "コメント者#{index + 1}-#{i + 1}",
      content: "とても参考になりました。#{[ '勉強になります！', 'ありがとうございます。', '続きが楽しみです。', 'わかりやすい解説でした。' ].sample}"
    ) do |comment|
      # published_atがnilの場合はcreated_atを使用
      base_time = article.published_at || article.created_at
      comment.created_at = base_time + rand(1..10).days
    end
  end
end

# 英語記事へのコメント
Article.where(locale: 'en', status: :published).each_with_index do |article, index|
  rand(1..2).times do |i|
    Comment.find_or_create_by(
      article: article,
      author_name: "User#{index + 1}-#{i + 1}",
      content: "#{[ 'Great article!', 'Very helpful, thanks!', 'Looking forward to more.', 'Well explained.' ].sample}"
    ) do |comment|
      comment.website = [ '', 'https://example.com', 'https://github.com/user' ].sample
      # published_atがnilの場合はcreated_atを使用
      base_time = article.published_at || article.created_at
      comment.created_at = base_time + rand(1..7).days
    end
  end
end

puts "管理者ユーザーを作成しました: #{admin_user.email}"
puts "テストユーザーを作成しました: #{test_user.email}"
puts 'Admin user created!'
puts 'Login credentials:'
puts 'Email: admin@example.com'
puts 'Password: password'
puts '========================================='

puts 'Seed data creation completed!'
puts "Total Articles: #{Article.count}"
puts "Japanese Articles: #{Article.where(locale: 'ja').count}"
puts "English Articles: #{Article.where(locale: 'en').count}"
puts "Categories (ja): #{Category.where(locale: 'ja').count}"
puts "Categories (en): #{Category.where(locale: 'en').count}"
puts "Total Users: #{User.count}"
