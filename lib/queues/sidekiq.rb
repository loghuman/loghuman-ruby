class LogHumanSidekiqWorker
  include Sidekiq::Worker

  def perform ( payloads )
    LogHuman.api( payloads )
  end

end
