class RunProviderJob < ApplicationJob
  queue_as :default

  def perform(run)
    run.execute!
  ensure
    broadcast_update(run.reload)
  end

  private

  def broadcast_update(run)
    Turbo::StreamsChannel.broadcast_replace_to(
      run.experiment,
      target: "run_#{run.id}",
      partial: "experiments/run",
      locals: { run: run }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      run.experiment,
      target: "experiment_status",
      partial: "experiments/status",
      locals: { experiment: run.experiment.reload }
    )
  end
end
