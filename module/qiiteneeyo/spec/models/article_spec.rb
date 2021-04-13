require 'rails_helper'

DEFAULT_TEST_PARAMS = {
  url: 'https://www.example.com',
  title: 'タイトル',
  body: '# 主題\n## 副題\n本文',
  user: 'test_user',
  created_at: '2021-04-03T10:25:50+09:00',
  updated_at: '2021-04-03T10:25:50+09:00',
}

RSpec.describe Article, type: :model do
  let(:article) { Article.new(params) }
  describe 'new' do
    subject{ article }
    context 'having url, title, body, user, created_at, updated_at' do
      let(:params) { DEFAULT_TEST_PARAMS }
      it { is_expected.to be_valid }
      it 'has disctionaries' do
        expect( subject.dictionary_positive.class ).to be Hash
        expect( subject.dictionary_positive['keywords'].class ).to be Array
        expect( subject.dictionary_negative.class ).to be Hash
        expect( subject.dictionary_negative['keywords'].class ).to be Array
      end
    end
    context 'lacking url' do
      let(:params) { DEFAULT_TEST_PARAMS.reject{|k,v| k==:url} }
      it { is_expected.not_to be_valid }
    end
    context 'lacking title' do
      let(:params) { DEFAULT_TEST_PARAMS.reject{|k,v| k==:title} }
      it { is_expected.not_to be_valid }
    end
    context 'lacking body' do
      let(:params) { DEFAULT_TEST_PARAMS.reject{|k,v| k==:body} }
      it { is_expected.not_to be_valid }
    end
    context 'lacking user' do
      let(:params) { DEFAULT_TEST_PARAMS.reject{|k,v| k==:user} }
      it { is_expected.not_to be_valid }
    end
    context 'lacking created_at' do
      let(:params) { DEFAULT_TEST_PARAMS.reject{|k,v| k==:created_at} }
      it { is_expected.not_to be_valid }
    end
    context 'lacking updated_at' do
      let(:params) { DEFAULT_TEST_PARAMS.reject{|k,v| k==:updated_at} }
      it { is_expected.not_to be_valid }
    end
  end
  describe 'curate' do
    let(:params) { DEFAULT_TEST_PARAMS }

    # Using shorthand defined in outer group
    let(:pw) { positive_words }
    let(:nw) { negative_words }
    let(:positive_words) { article.dictionary_positive['keywords'] }
    let(:negative_words) { article.dictionary_negative['keywords'] }

    subject { article.curate }

    context 'with random positive word' do
      it 'is positive and result' do
        3.times do
          article.title = "About #{pw[rand(0..pw.length-1)]}"
          is_expected.to be true
        end
      end
    end
    context 'without random positive word' do
      it 'is positive and result' do
        article.title = "About spam spam spam..."
        is_expected.to be false
      end
    end
    context 'with both random positive and negative word' do
      it 'is negative and result' do
        3.times do
          article.title = "About #{pw[rand(0..pw.length-1)]} and #{nw[rand(0..nw.length-1)]}"
          is_expected.to be false
        end
      end
    end
  end
end
