require 'rails_helper'
require 'byebug'

Time.zone = 'UTC'

RSpec.describe Draft, type: :model do
  let(:draft) { Draft.new(params) }
  describe 'initialize' do
    context 'without params' do
      let(:params) { {} }
      describe 'title of draft' do
        subject { draft.title }

        it 'which has defined format' do
          is_expected.to match(/Qiita トラブルシューティング・失敗集 【\(半\)自動更新: [0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日】/)
        end
        it 'is not writable from outside' do
          expect { draft.title = "Some words" }.to raise_error(NoMethodError)
        end

        describe 'date in title is in JST timezone' do
          before { Time.zone ='Tokyo' }
          after { Time.zone ='UTC' }

          subject { draft.title[/[0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日/] }
          context 'the last second in JST' do
            before { travel_to(Time.zone.local(2020, 12, 31, 23, 59, 59)) }
            after { travel_back }

            it 'has date of 2021/12/31' do
              is_expected.to match('2020年12月31日')
            end

          end
          context 'the first second in JST' do
            before { travel_to(Time.zone.local(2021, 1, 1, 0, 0, 0)) }
            after { travel_back }

            it 'has date of 2021/1/1' do
              is_expected.to match('2021年1月1日')
            end

          end
        end
      end
      describe 'tags of draft' do
        subject { draft.tags }
        let(:tags){
          [
            { name: "Qiita" },
            { name: "トラブルシューティング" },
            { name: "失敗集" }
          ]
        }

        it 'which has array with defined values' do
          is_expected.to eq tags
        end
        it 'is not writable from outside' do
          expect { draft.tags = [{name: 'test'}] }.to raise_error(NoMethodError)
        end
      end
      describe 'private flag of draft' do
        subject { draft.private }

        it 'which is fixed' do
          is_expected.to be true
        end        
      end
      describe 'body of draft' do
        subject { draft.body }

        it 'which is empty' do
          is_expected.to be nil
        end
        it 'is  writable from outside' do
          expect{ draft.body = 'Some words' }.not_to raise_error
          # After that
          expect( subject ).to eq 'Some words'
        end
      end
    end
  end
  describe 'publish' do
    # Includes tests for dependancy: unshift_preface, unshift_statistics
    let(:params) { {} }
    subject { draft.publish }

    it 'returns json string to upload' do
      expect( subject.class.name ).to eq 'String'
      expect{ JSON.parse(subject) }.not_to raise_error
    end

    describe 'body of draft' do
      before { Time.zone ='Tokyo' }
      after { Time.zone ='UTC' }
      before { draft.body = 'Some words' }
      subject { draft.body }

      describe 'common output' do
        before { draft.publish }

        it 'includes preface' do
          is_expected.to match(/.*集計方法: Qiita APIにて作成時間基準で7日前の日付を 'Create:>' に指定.*/)
          is_expected.to match(/.*予定掲載期間: [0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日　まで.*/)
          is_expected.to match(/.*この記事は期間終了後に消えるBOT記事です。.*/)
          is_expected.to match(/.*こちらの記事にストックおよびLGTMはしないでください。.*/)
        end
        it 'includes statistics' do
          is_expected.to match(/.*# 統計情報*/)
          is_expected.to match(/.*期中における \[抽出記事数 \/ Qiita全投稿数\] : [0-9]+ \/ [0-9]+.*/)
        end
      end
      describe 'publication deadline in preface' do
        subject { draft.body[/[0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日　まで/] }

        context 'in a day and last second in JST' do
          before { travel_to(Time.zone.local(2021, 1, 1, 23, 59, 59)) }
          before { draft.publish }
          after { travel_back }

          it 'has date of 2021/1/29' do
            is_expected.to match('2021年1月29日　まで')
          end
        end
        context 'in another day and first second in JST' do
          before { travel_to(Time.zone.local(2021, 2, 27, 0, 0, 0)) }
          before { draft.publish }
          after { travel_back }

          it 'has date of 2021/3/27' do
            is_expected.to match('2021年3月27日　まで')
          end
        end
      end
    end
  end
  describe 'section' do
    let(:entry) { { 'title'=>title, 'url'=>url, 'user'=>user, 'created_at'=>time_exp} }
    subject { Draft.section(entry) }
    context 'a set of entry' do
      let(:title) { 'テスト' }
      let(:url) { 'https://www.example.com' }
      let(:user) { 'test_user' }
      let(:time_exp) { '2021-04-01T00:00:00+09:00' }
      it 'parses entry' do
        is_expected.to eq "## テスト\nURL: https://www.example.com\n[@test_user](https://qiita.com/test_user)さん(Created at: 2021-04-01T00:00:00+09:00)\n\n"
      end
    end
    context 'another set of entry' do
      let(:title) { 'タイトル' }
      let(:url) { 'https://www.example.com/path/to/url' }
      let(:user) { 'example_user' }
      let(:time_exp) { '2021-04-03T10:25:50+09:00' }
      it 'parses entry' do
        is_expected.to eq "## タイトル\nURL: https://www.example.com/path/to/url\n[@example_user](https://qiita.com/example_user)さん(Created at: 2021-04-03T10:25:50+09:00)\n\n"
      end
    end
    context 'invalid entry' do
      let(:entry) { { 'url'=>url, 'user'=>user, 'created_at'=>time_exp} }
      let(:url) { 'https://www.example.com/path/to/url' }
      let(:user) { 'example_user' }
      let(:time_exp) { '2021-04-03T10:25:50+09:00' }
      it 'raises custom error' do
        expect{ subject }.to raise_error(DraftConversionError)
      end
    end
    context 'given not hash' do
      let(:entry) { ['value', 'value'] }
      it 'raises custom error' do
        expect{ subject }.to raise_error(DraftConversionError)
      end
    end
  end
end
