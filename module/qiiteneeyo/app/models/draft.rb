class DraftConversionError < StandardError
end

class Draft
  include ActiveModel::Model
  attr_reader :title, :tags, :private
  attr_accessor :body

  def initialize(attributes={})
    super
    @title = "Qiita トラブルシューティング・失敗集 【(半)自動更新: #{Time.current.strftime('%Y年%-m月%-d日')}】"
    @tags = [
      { name: "Qiita" },
      { name: "トラブルシューティング" },
      { name: "失敗集" }
    ]
    @private = true
  end

  def publish(stock_count: 0, preserve_count: 0)
    heading = "# 記事一覧\n"
    @body = "#{heading}#{@body}"
    unshift_statistics(stock_count, preserve_count) if stock_count && preserve_count > 0
    unshift_preface
    JSON.dump({
      title: @title,
      body: @body,
      tags: @tags,
      private: @private
    })
  end

  def self.section(entry)
    begin
      unless entry.has_key?('title') && entry.has_key?('url') && entry.has_key?('user') && entry.has_key?('created_at')
        raise DraftConversionError.new('lacking expected keys')
      end
    rescue NoMethodError
      raise DraftConversionError.new('entry should be hash')
    end
    "## #{entry['title']}\nURL: #{entry['url']}\n[@#{entry['user']}](https://qiita.com/#{entry['user']})さん(Created at: #{entry['created_at']})\n\n"
  end

  private
  def unshift_preface
    document = ""\
    "集計方法: Qiita APIにて作成時間基準で7日前の日付を 'Create:>' に指定\n"\
    "予定掲載期間: #{(Time.current + 28.day).strftime('%Y年%-m月%-d日')}　まで\n\n"\
    "**ご注意**\n"\
    "この記事は期間終了後に消えるBOT記事です。\n"\
    "良い記事があればリンク先の記事自体をストックまたはLGTMしてください。\n"\
    "こちらの記事にストックおよびLGTMはしないでください。\n"
    @body = "#{document}#{@body}"
  end

  def unshift_statistics(stock_count, preserve_count)
    document = ""\
    "# 統計情報\n"\
    "期中における [抽出記事数 / Qiita全投稿数] : #{stock_count} / #{preserve_count}\n"
    @body = "#{document}#{@body}"
  end
end
