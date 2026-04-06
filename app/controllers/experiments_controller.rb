class ExperimentsController < ApplicationController
  def index
    scope = Experiment.includes(:session, :runs).recent
    scope = scope.where(session_id: params[:session_id]) if params[:session_id].present?
    @grouped = scope.limit(200).group_by(&:session)
  end

  def show
    @experiment = Experiment.includes(:runs).find(params[:id])
  end

  def new
    @experiment = Experiment.new(session_id: params[:session_id])
    @available_providers = LLM::PROVIDERS.keys
    @sessions = Session.recent.limit(50)
  end

  def create
    provider_keys = params[:provider_keys]&.reject(&:blank?) || []

    @experiment = Experiment.new(
      name: params[:experiment][:name],
      prompt_text: params[:experiment][:prompt_text],
      system_prompt: params[:experiment][:system_prompt].presence,
      session_id: params[:experiment][:session_id].presence,
      status: "running"
    )

    if @experiment.save
      provider_keys.each do |key|
        provider = LLM.provider(key)
        run = @experiment.runs.create!(
          provider_key: key,
          model: provider.model,
          status: "pending"
        )
        RunProviderJob.perform_later(run)
      end

      redirect_to @experiment
    else
      @available_providers = LLM::PROVIDERS.keys
      render :new, status: :unprocessable_entity
    end
  end

  def rerun
    @experiment = Experiment.find(params[:id])
    run = @experiment.runs.find(params[:run_id])

    run.update!(status: "pending", response_text: nil, tokens_in: nil, tokens_out: nil,
                estimated_cost: nil, duration_ms: nil, error_message: nil)
    @experiment.update!(status: "running")
    RunProviderJob.perform_later(run)

    redirect_to @experiment
  end

  def destroy_run
    @experiment = Experiment.find(params[:id])
    run = @experiment.runs.find(params[:run_id])
    run.destroy!
    @experiment.check_completion!

    redirect_to @experiment
  end

  def run_model
    @experiment = Experiment.find(params[:id])
    keys = params[:provider_keys]&.reject(&:blank?) || []

    keys.each do |key|
      provider = LLM.provider(key)
      run = @experiment.runs.create!(
        provider_key: key,
        model: provider.model,
        status: "pending"
      )
      RunProviderJob.perform_later(run)
    end

    @experiment.update!(status: "running") if keys.any?

    redirect_to @experiment
  end
end
