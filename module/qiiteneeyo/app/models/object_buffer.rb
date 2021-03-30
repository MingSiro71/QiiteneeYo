class ObjectBuffer
  include ActiveModel::Model
  attr_reader :stream

  def initialize
    super
    clear
  end

  def clear
    @stream = []
  end

  def append(value)
    @stream.append value
    value
  end

  def size
    @stream.size
  end

  def store_local(path)
    file = File.open(path, 'w')
    file.write json_from_stream
  end

  def store_s3(path)
    client = Aws::S3::Client.new(
      region: ENV['QIITENEEYO_S3_REGION'],
    )
    client.put_object(
      bucket: ENV['QIITENEEYO_S3_BUCKET'],
      key: path,
      body: json_from_stream
    )
  end

  def to_draft
    draft = Draft.new
    draft.body = @stream.reduce("") do |acc, value|
      acc << "## #{value['title']}\nURL: #{value['url']}\n[@#{value['user']}](https://qiita.com/#{value['user']})さん(Created at: #{value['created_at']})\n\n"
    end
    draft
  end

  private
  def json_from_stream
    JSON.dump @stream
  end

  def aws_config

  end
end