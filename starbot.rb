require 'slack-ruby-client'
require 'json'
require 'cache'
require 'httparty'

require 'dotenv'
Dotenv.load

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

$api_path = "https://api.github.com/"

$usernames = []
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
    when "help"
      client.message channel: data['channel'], text: "#{usage}", as_user: true
    when "scoreboard"
      message = ""
      scoreboard.each_with_index do |(key, value), index|
        message += "#{index + 1}. #{key}\t-\t#{value} stars #{emoji(index)} \n"
      end
      client.message channel: data['channel'], text: "#{message}", as_user: false
    end
  end
end

def scoreboard
  scoreboard = {}
  $usernames.each do |username|
    scoreboard[username] = star_count(username)
  end
  scoreboard.sort_by(&:last).reverse
end

def star_count(username)
  query = $api_path + "users/#{username}/repos"
  response = JSON.parse(HTTParty.get(query).body)
  count = 0
  response.each do |project|
    count += project['stargazers_count']
  end
  count
end

def emoji(index)
  case index
  when 0
    ":trophy:"
  when 1
    ":sports_medal:"
  else
    ""
  end
end

client.start!