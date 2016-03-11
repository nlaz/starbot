# Starbot
A simple Slackbot application scoreboard for OSS contributors based on the number of stars gained on their projects.
## Setup

These are the steps to get the app up and running:

###  Step 1. Clone this repository
Make a local copy of this project and move into the directory. This project requires Ruby and RubyGems.
```
  $ git clone https://github.com/nlaz/starbot.git
  $ cd starbot
```

### Step 2. Create a bot for your Slack 
Create a new 'Bot' configuration for your team and customize the information. Record the API Token in a file named `.env` in your project directory like so:
```
  SLACK_API_TOKEN=[INSERT SLACK API TOKEN]
```  


### Step 3. Bundle and run locally
You now need to install the dependencies used in the project. You can do that using the Ruby bundler:
 
```
$ bundle install
```
You should now be able to run your bot locally and test it.  
```
$ ruby starbot.rb
```

### Contributing
Suggestions and pull requests are welcome! Any questions or suggestions can be sent to [@nikolazaris](https://twitter.com/nikolazaris). Cheers!