class GenerateTitleJob < ApplicationJob
  queue_as :default

  def perform(session)
    Recall::TitleGenerator.generate(session)
  end
end
