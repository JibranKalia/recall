class ImportsController < ApplicationController
  skip_forgery_protection only: :create

  def create
    Recall::Importer.import_all
    head :ok
  end
end
