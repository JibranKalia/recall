class ImportsController < ApplicationController
  def create
    ImportJob.perform_later

    head :ok
  end
end
