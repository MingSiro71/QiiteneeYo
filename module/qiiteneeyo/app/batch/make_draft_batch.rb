class MakeDraftBatch < ApplicationBatch
  def run
    controller = ArticlesController.new
    controller.search
    controller.upload
  end
end
