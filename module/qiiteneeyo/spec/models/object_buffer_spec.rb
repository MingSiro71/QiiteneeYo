require 'rails_helper'

TEST_ATTRIBUTES={ name: 'test', value: 100 }
TEST_ATTRIBUTES_MUTANT={ name: 'test', value: 105 }
DRAFT_COMPATIBLE_LINE={ 'title'=>'テスト', 'url'=>'https://www.example.com', 'user'=>'test_user', 'created_at'=>'2021-04-01T00:00:00+09:00' }

RSpec.describe ObjectBuffer, type: :model do
  let(:object_buffer) { ObjectBuffer.new }
  describe 'initialize' do
    describe 'stream attribute' do
      subject { object_buffer.stream }
      it 'initialized' do
        is_expected.to eq []
      end
    end
  end
  describe 'append' do
    it 'appends attribute at last' do
      object_buffer.append(TEST_ATTRIBUTES)
      object_buffer.append(TEST_ATTRIBUTES_MUTANT)
      object_buffer.append(TEST_ATTRIBUTES)
      expect(object_buffer.stream).to eq [
        TEST_ATTRIBUTES,
        TEST_ATTRIBUTES_MUTANT,
        TEST_ATTRIBUTES
      ]
    end
    it 'raises TypeError if given value is not attribute' do
      expect{ object_buffer.append('value') }.to raise_error TypeError
      expect{ object_buffer.append(100) }.to raise_error TypeError
      expect{ object_buffer.append(['value']) }.to raise_error TypeError
      expect{ object_buffer.append(ObjectBuffer.new) }.to raise_error TypeError
    end
  end
  describe 'size' do
    subject { object_buffer.size }
    it 'initially' do
      is_expected.to eq 0
    end
    it 'as appending attributes as' do
      cycle = 0
      10.times do
        cycle += 1
        object_buffer.append(TEST_ATTRIBUTES)
        expect(object_buffer.size).to eq cycle 
      end
    end
  end
  describe 'to_draft' do
    before { object_buffer.append(DRAFT_COMPATIBLE_LINE) }

    it 'returns draft' do
      expect(object_buffer.to_draft).to be_a(Draft)
    end
    it 'has markdown formatted stream' do
      expect(object_buffer.to_draft.body).to match(/## テスト/)
    end
  end
end
