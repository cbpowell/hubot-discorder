# Description:
#   A Hubot script to track users on a Mumble server.
#
# Dependencies:
#   node-redis
#   node-mumble
#
# Configuration:
#   HUBOT_REDIS_URL - URL for Redis server
#   HUBOT_MUMBLE_NICK - Username for Hubot on the Mumble server
#   HUBOT_MUMBLE_PASS - Password for Mumble server (if required)
#   HUBOT_MUMBLE_PATH - URL for Mumble server
#   HUBOT_MUMBLE_KEY - TLS Public key for certificate to connecto Mumble server (if required)
#   HUBOT_MUMBLE_CERT - TLS Public certificate to connect to Mumble server (if required)
#
# Commands:
#   mumble me - List users on Mumble, in all channels
#   who's online? - List users on Mumble, in all channels
#   anyone online - List users on Mumble, in all channels
#   anyone in/on <channel>? - Lists users on Mumble, in specified channel
#   who's in/on <channel>? - Lists users on Mumble, in specified channel
#
# Author:
#   cbpowell

Url = require 'url'
Redis = require 'redis'
fs = require 'fs'
Mumbler = require 'mumble'

RedisStorage = require './redis-storage'

String::strip = ->
  if String::trim? then @trim() else @replace /^\s+|\s+$/g, ""

module.exports = (robot) ->

  # Configure redis the same way that redis-brain does.
  redisInfo = Url.parse process.env.REDISTOGO_URL or
    process.env.REDISCLOUD_URL or
    process.env.BOXEN_REDIS_URL or
    process.env.REDIS_URL or
    'redis://localhost:6379'
  client = Redis.createClient(redisInfo.port, redisInfo.hostname, {no_ready_check: true})

  if redisInfo.auth
    console.log("Mumbler redis authing")
    client.auth redisInfo.auth.split(":")[1]
    
  # Configure Mumble interface
  options =
    nick:     process.env.HUBOT_MUMBLE_NICK or robot.name
    path:     process.env.HUBOT_MUMBLE_PATH
    password: process.env.HUBOT_MUMBLE_PASSWORD
  
  mumbleOptions =
    key:  process.env.HUBOT_MUMBLE_KEY
    cert: process.env.HUBOT_MUMBLE_CERT
  
  storage = new RedisStorage(client)
  #model = new MumblerModel(storage)
  
  # Initiate Mumble connection
  mumbler = new Mumbler.connect options.path, mumbleOptions, (error, connection) ->
    throw new Error(error) if error
    
    # Authenticate and initialize
    connection.authenticate options.nick, options.password
    
    connection.on "initialized", ->
      console.log "Mumble connection initialized"
      
      # Clear users and rooms
      storage.clearUsers()
      storage.clearChannels()
      
      # Gather users
      users = connection.users
      storage.updateUsers(users)
    
    connection.on 'channelState', (state) ->
      unless state.channelId is null or state.name is null
        storage.updateChannel(state.channelId, state.name)
		
    connection.on "user-update", (user) ->
      userName = user.name
      channel = user.channelId
      
      # Get current location for user
      storage.locationsForUsers userName, (err, previousChannel) ->
        # Update user
        storage.updateUser(userName, channel)
      
        # Filter updates about self
        if userName is options.nick
          return
      
        # Filter non-room changes
        if channel is previousChannel
          return
        
        storage.channelNamesForIds channel, (err, channelName) ->
          # Check type of update
          if channelName?
            message = "_#{userName}_ moved into #{channelName}"
          else
            message = "_#{userName}_ hopped on Mumble!"
      
          # Update room(s)
          robot.messageRoom process.env.HUBOT_MUMBLE_ANNOUNCE_ROOMS, message
    
    connection.on "user-remove", (user) ->
      console.log "User disconnected:", user
      storage.updateUser(user.name)
      
    connection.on "text-message", (textMessage) ->
      console.log "Text message:", textMessage
  
  robot.hear /(mumble me$)|(who'?s online\?)|(anyone ((online)|(on mumble))\??)/i, (msg) ->
    storage.onlineUsers (users, channels) ->
      message = "🎮 Online:"
      for channelName, users of channels
        message = message + " (#{channelName}) "
        for u in users
          unless u is robot.name
            message = message + "_#{u}_, "
      
      message = message.substring(0, message.length - 2)
      msg.send message
    
  robot.hear /(?:mumble me (.+))|(?:(?:anyone|who'?s) (?:in|on) (.+)\?)/i, (msg) ->
    channel = msg.match[1] or msg.match[2]
    if not channel?
      msg.send "Not a valid channel 😬"
      return
    
    storage.onlineUsers (users, channels) ->
      message = ''
      unless channels is not null and channels.length > 0
        for channelName, users of channels
          if channel.toLowerCase() is channelName.toLowerCase()
            if users is not null and users.length > 0
              message = "🎮 Online in #{channelName}:"
              for u in users
                unless u is robot.name
                  message = message + "_#{u}_, "
            message = message.substring(0, message.length - 2)
            
      if message is null or message.length is 0
        message = "No one in #{channel} 😕"
                  
      msg.send message
