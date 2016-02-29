require 'slack-ruby-client'
require 'json'
require 'cache'
require 'httparty'

require 'dotenv'
Dotenv.load

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

client = Slack::RealTime::Client.new

client.on :hello do
  puts 'Successfully connected.'
end

client.on :message do |data|
  puts data
  case data['text']
  when /test/ then
    client.message channel: data['channel'], text: "Hi <@#{data['user']}>!"
  end
end

client.start!