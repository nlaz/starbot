require 'slack-ruby-client'
require 'json'
require 'cache'
require 'httparty'

require 'dotenv'
Dotenv.load

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

usernames = []
usage = "Starbot - A GitHub user scoreboard for starred repos\n" \
        "Usage: \n" \
        "`@starbot help` - Displays all of the help commands that starbot knows about.\n" \
        "`@starbot add <username>` - Add a username to scoreboard.\n" \
        "`@starbot scoreboard` - Display all user scores.\n"

client = Slack::RealTime::Client.new

client.on :hello do
  puts 'Successfully connected.'
end

client.on :message do |data|
  client_id = "<@#{client.self['id']}>"
  command = data['text']

  if (command[client_id] == client_id)
    command = command[client_id.length+1..-1].lstrip

    case command
    when "help" then
      client.message channel: data['channel'], text: "#{usage}", as_user: true
    when "scoreboard" then
      puts usernames
    end
  end
end

client.start!