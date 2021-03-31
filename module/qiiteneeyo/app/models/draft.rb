class Draft
  include ActiveModel::Model
  attr_reader :title, :preface, :tags, :private
  attr_accessor :body
  
  def initialize(attributes={})
    super
    @title = "Qiita トラブルシューティング・失敗集 【(半)自動更新: #{Date.today().strftime('%Y年%m月%d日')}】"
    @preface = "# About this\n# 集計記事"
    @tags = [
      { name: "Qiita" },
      { name: "トラブルシューティング" },
      { name: "失敗集" }
    ]
    @private = true
  end

  def publish
    JSON.dump({
      title: title,
      body: body,
      tags: tags,
      private: true
    })
  end

end
