require 'rails_helper'
require 'byebug'

RSpec.describe Draft, type: :model do
  describe 'an initialized instance' do 
    let(:draft) { Draft.new(params) }
    let(:params) { {} } 
    describe 'has a title' do
      subject { draft.title.match(/Qiita トラブルシューティング・失敗集 【(半)自動更新: [0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日】/) }
      it 'is has a format' do
        is_expected.not_to be nil
      end
      subject { Proc.new {draft.title = "Some words" } }
      it 'is immutable' do
        is_expected.to raise_error(NoMethodError)
      end
    end
    describe 'title has date in JST timezone' do
      let(:timestring) { Time.current.in_time_zone('Tokyo').strftime('%Y年%m月%d日') }
      subject { draft.title[/[0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日/] }
      it 'consist in case 23:59 JST' do
        travel_to('2020-12-31 23:59'.to_time.in_time_zone('Tokyo'))
        is_expected.to eq timestring
      end
      it 'consist in case 0:00 JST' do
        travel_to('2021-01-01 0:00'.to_time.in_time_zone('Tokyo'))
        is_expected.to eq timestring
      end
    end
  end
end
