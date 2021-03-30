class Article
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :url
  attribute :title
  attribute :body
  attribute :user
  attribute :created_at
  attribute :updated_at
  validates :url, presence: true, on: :curate
  validates :title, presence: true, on: :curate
  validates :body, presence: true, on: :curate
  validates :user, presence: true, on: :curate
  validates :created_at, presence: true, on: :curate
  validates :updated_at, presence: true, on: :curate

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
