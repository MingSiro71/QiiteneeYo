class MakeDraftBatch < ApplicationBatch
  def run
    controller = ArticlesController.new
    controller.search
    controller.upload
    controller.expire
  end
end
