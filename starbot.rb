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
        "`@starbot today` - Display who has committed today.\n" \
        "`@starbot streaks` - Display latest streak for all users.\n" \
        "`@starbot contribs` - Display number of contributions for all users.\n" \
        "`@starbot longest streak` - Display longest contribution streaks for all users.\n"

# Class Helpers

class Starbot < Slack::RealTime::Client
  def speak(text, data)
    self.message channel: data['channel'], text: text
  end
end

client = Starbot.new

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
      client.speak("#{usage}", data)
    when "scoreboard"
      client.speak("#{scoreboard_message}", data)
    when "streaks"
      client.speak("#{current_streak_message}", data)
    when "contribs"
      client.speak("#{total_contributions_message}", data)
    when "longest streak"
      client.speak("#{longest_streak_message}", data)
    when "today"
      client.speak("#{daily_commit_message}", data)
    when "highfive!"
      client.speak("Woot! Highfive! :hand:", data)
    when "night night"
      client.speak("Goodnight! :zzz:", data)
    when "users"
      client.speak("*Here's the list of current users...*\n#{usernames.join(', ')}", data)
    when /^add[ ]/i
      user = command[4..-1]
      if usernames.include? user
        client.speak("Oops! #{user} is already on our list.", data)
      else
        client.client.speak("Adding user... #{user}", data)
        if add_user(user)
          client.speak("Success! Added #{user} :tada:\n#{scoreboard_message}", data)
        else
          client.speak("Error! Invalid user: #{user}...", data)
        end
      end
    when /^remove[ ]/i
      user = command[7..-1]
      client.speak("Removing user... #{user}",data)
      if remove_user(user)
        client.speak("Success! Removed #{user} from the scoreboard.\n#{scoreboard_message}", data)
      else
        client.speak("Error! User #{user} not found.", data)
      end
    else
      client.speak("Oops! Unable to recognize command. Please try again.\n#{usage}", data)
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

# TODO combine contributions and streaks
# TODO add longest streak
def total_contributions_message
  contribution_message(0)
end

def longest_streak_message
  contribution_message(1)
end

def current_streak_message
  contribution_message(2)
end

def contribution_message(number)
  dictionary = Hash.new do |hash, key|
    doc = Nokogiri::HTML(open("https://github.com/#{key}"))
    hash[key] = doc.css('.contrib-number')[number].content
  end
  usernames.each { |username| dictionary[username] }
  # TODO Sort streaks
  dictionary.map { |(key, value)| "#{key}\t-\t#{value} \n" }.join
end

def daily_commit_message
  dictionary = {}
  usernames.each do |username|
    doc = Nokogiri::HTML(open("https://github.com/#{username}"))
    date = Date.today.strftime('%F')
    rect = doc.css("rect[data-date='#{date}']")
    dictionary[username] = rect.first.attributes['data-count'].value
  end
  dictionary.map { |(key, value)| "#{key}\t-\t#{value} commits today! \n" }.join
end

def scoreboard
  scoreboard = Hash.new { |hash, key| hash[key] = star_count(key) }
  usernames.each { |username| scoreboard[username] }
  scoreboard.sort_by(&:last).reverse
end

def scoreboard_message
  messages = scoreboard.map.with_index do |(key, value), index| 
    "#{index + 1}. #{key}\t-\t#{value} stars #{emoji(index)} \n"
  end
  messages.join
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