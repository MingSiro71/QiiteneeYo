class ObjectBuffer
  include ActiveModel::Model
  attr_reader :stream

  def initialize
    super
    @stream = []
  end

  def append(hash)
    raise TypeError.new('required Hash') unless hash.class == Hash
    @stream.append hash
    hash
  end

  def size
    @stream.size
  end

  def store_local(path)
    file = File.open(path, 'w')
    file.write json_from_stream
    true
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
    true
  end

  def to_draft
    draft = Draft.new
    draft.body = @stream.reduce("") do |acc, line|
      acc << Draft.section(line)
    end
    draft
  end

  private
  def json_from_stream
    JSON.dump @stream
  end
end