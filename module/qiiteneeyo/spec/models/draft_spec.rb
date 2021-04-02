require 'rails_helper'
require 'byebug'

RSpec.describe Draft, type: :model do
  describe 'an initialized instance' do 
    let(:draft) { Draft.new(params) }
    let(:params) { {} } 
    describe 'has a title' do
      # subject { draft.title }
      expected(draft.title).to be match(/Qiita トラブルシューティング・失敗集 【(半)自動更新: [0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日】/)
      subject 'is immutable'
      expect{ draft.title = "Some words" }.to raise_error(NoMethodError)
      # subject { Proc.new { draft.title = "Some words" } }
      # it 'is immutable' do
      #   is_expected.to raise_error(NoMethodError)
      # end
    end
    describe 'title has date in JST timezone' do
      let(:timestring) { Time.current.in_time_zone('Tokyo').strftime('%Y年%m月%d日') }
      subject { draft.title[/[0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日/] }
      context 'consist in case 23:59 JST' do
        it 'is date before 0:00 JST' do
          travel_to('2020-12-31 23:59'.to_time.in_time_zone('Tokyo'))
          is_expected.to eq timestring
        end
      end
      context 'consist in case 00:00 JST' do
        it 'is date after 0:00 JST' do
          travel_to('2021-01-01 0:00'.to_time.in_time_zone('Tokyo'))
          is_expected.to eq timestring
        end
      end
    end
    describe 'has tags' do
      subject { draft.tags }
      it 'is defined value' do
        is_expected.to eq [ {name: "Qiita"}, { name: "トラブルシューティング" }, { name: "失敗集" } ]
      end
      # subject { Proc.new { draft.title = "Some words" } }
      # it 'is immutable' do
      #   is_expected.to raise_error(NoMethodError)
      # end
      # subject { Proc.new { draft.tags = [] } }
      # it 'is immutable' do
      #   is_expected.to raise_error(NoMethodError)
      # end
    # end
    # describe 'has tags' do
    end
  #   describe 'has private flag' do
  #     subject { draft.private }
  #     it 'is true' do
  #       is_expected.to be true
  #     end
  #     subject { Proc.new {draft.private = "Some words" } }
  #     it 'is immutable' do
  #       is_expected.to raise_error(NoMethodError)
  #     end
  #   end
  # end
  # let(:params) { { body: "Body for test" } }
  # describe 'unshift_preface' do
  #   subject { draft.body }
  #   it 'has string in body which is given in initialize' do
  #     is_expected.to eq "Body for test"
  #   end
    # it 'is attached preface' do
    #   is_expected.not_to eq "Body for test"
    #   subject { draft.body.match(/.+Body for test$/) }
    #   is_expected.not_to be nil
    # end
  end
end
