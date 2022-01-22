# Description:
#   A Hubot script to track users on a Discord server, nicknamed Mumbot
#
# Dependencies:
#   Discord.js
#
# Configuration:
#   HUBOT_DISCORDER_NICK - Username for Mumbot on the Mumble server
#   HUBOT_DISCORDER_TOKEN - Discord app token for bot-type
#   HUBOT_DISCORDER_GUILD - Discord guild ID to listen on
#   HUBOT_DISCORDER_ANNOUNCE_ROOMS - Rooms to make announcements in
#   HUBOT_DISCORDER_SHOULD_ANNOUNCE_ROOM_CHANGES - (True/False) Specifies if room changes should be announced. The first voice channel join will always be announced.
#   HUBOT_DISCORDER_ANNOUNCE_HIDDEN_ROOMS - Defines if robot should announce updates for rooms/channels that it does not have permission to enter (i.e. private rooms that the bot is not role'd to access). Defaults to false.
#
# Commands:
#   mumble me - List users on Discord, in all channels
#   who's online? - List users on Discord, in all channels
#   anyone online - List users on Discord, in all channels
#   anyone in/on <channel>? - Lists users on Discord, in specified channel
#   who's in/on <channel>? - Lists users on Discord, in specified channel
#
# Author:
#   cbpowell

Url = require 'url'
Discord = require 'discord.js'

String::strip = ->
  if String::trim? then @trim() else @replace /^\s+|\s+$/g, ""
  
create_quiet_username = (username) ->
  quietUsername = []
  for x in username
    quietUsername.push x
    quietUsername.push "\u200B"
  
  quietUsername.join("")
  
getAllIndexes = (arr, val) ->
  indexes = []
  i = 0
  while i < arr.length
    if arr[i] == val
      indexes.push i
    i++
  indexes


module.exports = (robot) ->
  # Configure Mumble interface
  options =
    nick:     process.env.HUBOT_DISCORDER_NICK or robot.name
  
  # Initiate Discord connection
  mumbler = new Discord.Client(intents: ["GUILDS","GUILD_MESSAGES","GUILD_PRESENCES","GUILD_VOICE_STATES"])
  
  token = process.env.HUBOT_DISCORDER_TOKEN
  
  mumbler.on "ready", ->
    console.log "Discord connection ready!"
    
  mumbler.on "voiceStateUpdate", (oldState, newState) ->
    if not newState?
      logNick = oldState.member.displayName ? "[[Unknown]]"
      console.log "Discorder: Update for #{logNick}: no newState object, assuming this was a part and ignoring"
      return
  
    # Check if the user update is for joining a channel, not leaving
    if not newState.channel?
      console.log "Discorder: Update for #{newState.displayName}: moved to no-channel, assuming this was a part and ignoring"
      return

    # Check if this is a channel change, return if not
    if newState.channelId is oldState.channelId
      console.log "Discorder: Update for #{newState.displayName}: change not related to voice channel, ignoring"
      return
  
    # Check if the a channel change should be announced
    if not process.env.HUBOT_DISCORDER_SHOULD_ANNOUNCE_ROOM_CHANGES
      if oldState.channel?
        # If the old member has a voice channel, this is not the initial join, do not announce
        console.log "Discorder: Update for #{newState.displayName}: user has prior voice channel, and room change announce is set to OFF, ignoring"
        return

    memberName = newState.member.displayName
    channelName = newState.channel.name

    console.log "new Channel: ", newState.channel.viewable

    # Filter updates about self
    if memberName is options.nick
      console.log "Discorder: Update is about the robot itself, ignoring"
      return

    # Check for null username
    if memberName is null
      console.log "Discorder: Update for #{oldState.displayName}: update member name is null, ignoring"
      return
  
    # Check if room is viewable to robot
    announceUnviewable = process.env.HUBOT_DISCORDER_ANNOUNCE_HIDDEN_ROOMS ? false
    if not announceUnviewable and not newState.channel.viewable
      console.log "Discorder: new channel for #{newState.displayName} is unviewable to robot, ignoring"
      return

    # Update room(s)
    quietName = create_quiet_username(memberName)
    console.log "Discorder: Update for #{memberName}: created quiet name (#{quietName}), announcing"
    message = "🎮 #{quietName} moved into #{channelName}"
    robot.messageRoom process.env.HUBOT_DISCORDER_ANNOUNCE_ROOMS, message
  
  mumbler.on "disconnect", (event) ->
    console.log "Discord has disconnected."
    
  mumbler.on "reconnecting", (event) ->
    console.log "Discord is attempting to reconnect."
    
  mumbler.on "error", (error) ->
    if error.message?
      console.log "Discord error: #{error.message}"
  
  # Login
  mumbler.login token
  
  robot.hear /(mumble me$)|(discord me$)|(who'?s online\?)|(anyone ((online)|(on mumble)|(on discord))\??)/i, (msg) ->
    # Get guild
    guild = mumbler.guilds.cache.first
    
    if not guild?
      console.log "Failed to find any guild in cache"

    if guild.id is not process.env.HUBOT_DISCORDER_GUILD
      console.log "Wrong guild! #{guild.name}"
      return
      
    # Get members
    allMembers = guild.members.fetch()
    ignored = [options.nick]
    # Filter members based on ignored, and connected status
    members = allMembers.filter (member) ->
      if member.nickname in ignored or member.user.username in ignored
        return false
      if not member.voice.channel?
        return false
      return true
    
    nicknames = members.map (member) ->
      return member.displayName
    channels = members.map (member) ->
      return member.voiceChannel.name
    
    #console.log "Nicknames: #{nicknames}"
    #console.log "Channels: #{channels}"
    
    uniqueChannels = channels.filter((x, i, a) => a.indexOf(x) == i)
    
    if members.length is 0
      message = "No one on Discord 😕"
    else
      message = "🎮 Online:"
      for id, chan of uniqueChannels
        idxs = getAllIndexes(channels, chan)
        message = message + " [#{chan}] "
        for idx in idxs
          if nicknames[idx]?
            u = create_quiet_username(nicknames[idx])
            message = message + "#{u}, "
      
        
        message = message.substring(0, message.length - 2)
        
    msg.send message
    
  robot.hear /(?:mumble me (.+))|(?:(?:anyone|who'?s) (?:in|on) (.+)\?)/i, (msg) ->
    reqChannel = msg.match[1] or msg.match[2]
    if not channel?
      msg.send "Not a valid channel 😬"
      return
    
      # Get guild
      guild = mumbler.guilds.cache.first
    
      if not guild?
        console.log "Failed to find any guild in cache"

      if guild.id is not process.env.HUBOT_DISCORDER_GUILD
        console.log "Wrong guild! #{guild.name}"
        return
      
      # Get members
      allMembers = guild.members.fetch()
      ignored = [options.nick]
      # Filter members based on ignored, and connected status
      members = allMembers.filter (member) ->
        if member.nickname in ignored or member.user.username in ignored
          return false
        if not member.voice.channel?
          return false
        return true
    
      nicknames = members.map (member) ->
        return member.displayName
      channels = members.map (member) ->
        return member.voiceChannel.name
    
    #console.log "Nicknames: #{nicknames}"
    #console.log "Channels: #{channels}"
    
    if members.length is 0
      message = "No one in #{reqChannel} 😕"
    else
      message = "🎮 Online in #{reqChannel}:"
      for id, chan of channels
        idxs = getAllIndexes(channels, chan)
        message = message + " [#{chan}] "
        for idx in idxs
          u = create_quiet_username(nicknames[idx])
          message = message + "#{u}, "
      
      message = message.substring(0, message.length - 2)
    msg.send message
