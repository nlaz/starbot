require 'slack-ruby-client'
require 'json'
require 'cache'
require 'httparty'
require 'sqlite3'
require 'nokogiri'
require 'open-uri'

require 'dotenv'
Dotenv.load

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

$api_path = "https://api.github.com/"

usage = "*Starbot* - A scoreboard for starred GitHub users\n" \
        "`@starbot help` - Displays all of the help commands that starbot knows about.\n" \
        "`@starbot users` - Displays a list of all current users tracked by starbot\n" \
        "`@starbot add <username>` - Add a username to scoreboard.\n" \
        "`@starbot remove <username>` - Remove a username from the scoreboard.\n" \
        "`@starbot scoreboard` - Display all user scores.\n" \
        "`@starbot streaks` - Display latest streak for all users.\n"
        "`@starbot contribs` - Display number of contributions for all users.\n"

client = Slack::RealTime::Client.new

client.on :hello do
  puts 'Successfully connected.'
  init_db("test.db")
end

client.on :message do |data|
  client_id = "<@#{client.self['id']}>"
  command = data['text']

  if (command[client_id] == client_id)
    command = command[client_id.length+1..-1].lstrip

    case command
    when "help"
      client.message channel: data['channel'], text: "#{usage}"
    when "scoreboard"
      client.message channel: data['channel'], text: "#{scoreboard_message}"
    when "streaks"
      client.message channel: data['channel'], text: "#{current_streak_message}"
    when "contribs"
      client.message channel: data['channel'], text: "#{contribution_message}"
    when "highfive!"
      client.message channel: data['channel'], text: "Woot! Highfive! :hand:"
    when "night night"
      client.message channel: data['channel'], text: "Goodnight! :zzz:"
    when "users"
      client.message channel: data['channel'], text: "*Here's the list of current users...*"
      client.message channel: data['channel'], text: "#{usernames.join(', ')}"
    when /^add[ ]/i
      user = command[4..-1]
      if usernames.include? user
        client.message channel: data['channel'], text: "Oops! #{user} is already on our list."
      else
        client.message channel: data['channel'], text: "Adding user... #{user}"
        if add_user(user)
          client.message channel: data['channel'], text: "Success! Added #{user} :tada:"
          client.message channel: data['channel'], text: "#{scoreboard_message}"
        else
          client.message channel: data['channel'], text: "Error! Invalid user: #{user}..."
        end
      end
    when /^remove[ ]/i
      user = command[7..-1]
      client.message channel: data['channel'], text: "Removing user... #{user}"
      if remove_user(user)
        client.message channel: data['channel'], text: "Success! Removed #{user} from the scoreboard."
        client.message channel: data['channel'], text: "#{scoreboard_message}"
      else
        client.message channel: data['channel'], text: "Error! User #{user} not found."
      end
    else
      client.message channel: data['channel'], text: "Oops! Unable to recognize command. Please try again."
      client.message channel: data['channel'], text: "#{usage}"
    end
  end
end

# Helpers

def add_user(username)
  response = HTTParty.get($api_path + "users/#{username}")
  if response.code == 200
    $db.execute( "INSERT OR IGNORE INTO users (username) VALUES('#{username}')" )
    true
  elsif response.code == 404
    false
  end
end

def remove_user(username)
  if usernames.include? username
    $db.execute( "DELETE FROM users WHERE username='#{username}'" )
    true
  else
    false
  end
end

def init_db(db_name)
  $db = SQLite3::Database.new( db_name )
  $db.execute( "CREATE TABLE IF NOT EXISTS users (username VARCHAR (36) PRIMARY KEY)" )
  $db.execute( "SELECT * FROM users" ) do |user|
    p user
  end
end

def scoreboard
  scoreboard = {}
  usernames.each do |username|
    scoreboard[username] = star_count(username)
  end
  scoreboard.sort_by(&:last).reverse
end

def contributions
  contributions = {}
  usernames.each do |username|
    doc = Nokogiri::HTML(open("https://github.com/#{username}"))
    contributions[username] = doc.css('.contrib-number').first.content
  end
  contributions
end

def contribution_message
  message = ""
  contributions.each do |(key, value)|
    message += "#{key}\t-\t#{value} \n"
  end
  message
end

def current_streak
  current_streaks = {}
  usernames.each do |username|
    doc = Nokogiri::HTML(open("https://github.com/#{username}"))
    current_streaks[username] = doc.css('.contrib-number').last.content
  end
  current_streaks
end

def current_streak_message
  message = ""
  current_streak.each do |(key, value)|
    message += "#{key}\t-\t#{value} \n"
  end
  message
end

def scoreboard_message
  message = ""
  scoreboard.each_with_index do |(key, value), index|
    message += "#{index + 1}. #{key}\t-\t#{value} stars #{emoji(index)} \n"
  end
  message
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

def usernames
  usernames = []
  $db.execute( "SELECT * FROM users" ) do |user|
    usernames << user[0]
  end     
  usernames
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