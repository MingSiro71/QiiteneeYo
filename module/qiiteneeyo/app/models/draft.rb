class Draft
  include ActiveModel::Model
  attr_reader :title, :tags, :private
  attr_accessor :body
  
  def initialize(attributes={})
    super
    @title = "Qiita トラブルシューティング・失敗集 【(半)自動更新: #{Date.today().strftime('%Y年%m月%d日')}】"
    @tags = [
      { name: "Qiita" },
      { name: "トラブルシューティング" },
      { name: "失敗集" }
    ]
    @private = true
  end

  def publish(stock_count:, preserve_count:)
    heading = "# 記事一覧\n"
    @body = "#{heading}#{@body}"
    unshift_statistics(stock_count, preserve_count) if stock_count && preserve_count
    unshift_preface
    JSON.dump({
      title: @title,
      body: @body,
      tags: @tags,
      private: @private
    })
  end

  private
  def unshift_preface
    document = ""\
    "集計方法: Qiita APIにて作成時間基準で7日前の日付を 'Create:>' に指定\n"\
    "予定掲載期間: #{(Time.current + 28.day).strftime('%Y年%m月%d日')}　まで\n\n"\
    "**ご注意**\n"\
    "この記事は期間終了後に消えるBOT記事です。\n"
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
