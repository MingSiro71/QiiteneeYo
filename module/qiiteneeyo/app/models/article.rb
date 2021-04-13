class Article
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :url
  attribute :title
  attribute :body
  attribute :user
  attribute :created_at
  attribute :updated_at
  validates :url, presence: true
  validates :title, presence: true
  validates :body, presence: true
  validates :user, presence: true
  validates :created_at, presence: true
  validates :updated_at, presence: true

  attr_reader :dictionary_positive, :dictionary_negative

  def initialize(attributes={})
    super
    @dictionary_positive = Article::load_json_file Rails.root.join('db/static/', "dictionary_positive.json")
    @dictionary_negative = Article::load_json_file Rails.root.join('db/static/', "dictionary_negative.json")
  end

  def curate
    title = self.title
    positive = @dictionary_positive['keywords'].reduce(false) do |acc, key|
      acc ||= (title.include? key)
    end
    negative = @dictionary_negative['keywords'].reduce(false) do |acc, key|
      acc ||= (title.include? key)
    end
    (positive && !negative)
  end

  private
  def self.load_json_file(file)
    JSON.parse(File.open(file, 'r').read)
  end

end
