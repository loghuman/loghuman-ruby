require 'net/https'
require 'json'

class LogHuman

  DATA_ENDPOINT = 'https://data.loghuman.com/messages'
  STATUSES = [ :debug, :success, :info, :warning, :error ]

  @@context = nil
  @@messages = []

  @@api_key = nil

  def self.api_key= ( api_key )
    @@api_key = api_key
  end

  def self.send ( message, status, opts={} )

    if @@api_key.nil?
      raise "You must set an api key before sending messages: LogHuman.api_key = '*********'"
    end

    unless STATUSES.include?( status )
      raise "The message status must be one of #{STATUSES.join(', ')}"
    end

    payload = opts.merge( {
      message: message,
      status: status.to_s,
      timestamp: (Time.now.to_f * 1000).round,
      date: Time.now.strftime('%Y-%m-%d')
    } )

    if @@context.nil?
      self.execute( [payload] )
    else
      @@messages << payload.merge( {
        context: @@context
      } )
    end

  end

  def self.context ( context )
    @@context = context
    yield
    self.execute( @@messages )
    @@messages = []
  end

  def self.execute ( payloads )
    if defined? Sidekiq
      unless defined? LogHumanWorker
        require './queues/sidekiq'
      end
      LogHumanWorker.perform_async( payloads )
    else
      self.api( payloads )
    end
  end

  private

    def self.api ( payloads )
      uri = URI.parse( DATA_ENDPOINT )
      https = Net::HTTP.new( uri.host, uri.port )
      https.use_ssl = true
      req = Net::HTTP::Post.new( uri.path )
      req['User-Agent'] = 'LogHuman Gem 0.0.1'
      req.basic_auth( @@api_key, nil )
      req.body = JSON.generate( payloads )
      res = https.request( req )
      res.code == '201'
    end

end
