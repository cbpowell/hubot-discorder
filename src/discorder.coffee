# Description:
#   A Hubot script to track users on a Discord server, nicknamed Mumbot
#
# Dependencies:
#   Discord.js
#
# Configuration:
#   HUBOT_DISCORDER_NICK - Username for Mumbot on the Mumble server
#   HUBOT_DISCORDER_TOKEN - Discord app token for bot-type
#   HUBOT_DISCORDER_ANNOUNCE_ROOMS - Rooms to make announcements in
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
  usernameHead = username.slice(0, 1)
  usernameTail = username.slice(1, username.length)
  usernameHead + "\u200B" + usernameTail
  
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
    #path:     process.env.HUBOT_MUMBLE_PATH
  
  # Initiate Discord connection
  mumbler = new Discord.Client
  token = process.env.HUBOT_DISCORDER_TOKEN
  
  mumbler.on "ready", ->
    console.log "Discord connection ready!"
    
  mumbler.on "voiceStateUpdate", (oldMember, newMember) ->
    # Check if the user update is for joining a channel, not leaving
    if not newMember.voiceChannel?
      return
    
    # Check if this is a channel change, return if not
    if newMember.voiceChannel is oldMember.voiceChannel
      return
      
    memberName = newMember.nickname
    channelName = newMember.voiceChannel.name
  
    # Filter updates about self
    if memberName is options.nick
      return
    
    # Update room(s)
    quietName = create_quiet_username(memberName)
    message = "🎮 #{quietName} moved into #{channelName}"
    robot.messageRoom process.env.HUBOT_DISCORDER_ANNOUNCE_ROOMS, message
  
  mumbler.on "disconnect", (event) ->
    message = "/me disconnected from Discord 😩"
    robot.messageRoom robot.messageRoom process.env.HUBOT_DISCORDER_ANNOUNCE_ROOMS, message
    
  mumbler.on "reconnecting", (event) ->
    message = "/me is attempting to reconnect to Discord 🤔"
    robot.messageRoom robot.messageRoom process.env.HUBOT_DISCORDER_ANNOUNCE_ROOMS, message
  
  # Login
  mumbler.login token
  
  robot.hear /(mumble me$)|(discord me$)|(who'?s online\?)|(anyone ((online)|(on mumble)|(on discord))\??)/i, (msg) ->
    # Get guild
    guilds = mumbler.guilds.array()
    guild = guilds[0]
    if guild.name is not "The Psyjnir Complex"
      console.log "Wrong guild! #{guild.name}"
      return
    # Get members
    allMembers = guild.members.array()
    ignored = [options.nick]
    # Filter members based on ignored, and connected status
    members = allMembers.filter (member) ->
      if member.nickname in ignored
        return false
      if not member.voiceChannel?
        return false
      return true
    
    nicknames = members.map (member) ->
      return member.nickname
    channels = members.map (member) ->
      return member.voiceChannel.name
    
    #console.log "Nicknames: #{nicknames}"
    #console.log "Channels: #{channels}"
    
    if members.length is 0
      message = "No one on Discord 😕"
    else
      message = "🎮 Online:"
      for id, chan of channels
        idxs = getAllIndexes(channels, chan)
        message = message + " [#{chan}] "
        for idx in idxs
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
    guilds = mumbler.guilds.array()
    guild = guilds[0]
    if guild.name is not "The Psyjnir Complex"
      console.log "Wrong guild! #{guild.name}"
      return
      
    # Get members
    allMembers = guild.members.array()
    ignored = [options.nick]
    
    members = allMembers.filter (member) ->
      # Filter members based on ignored, and connected status
      if member.nickname in ignored
        return false
      if not member.voiceChannel?
        return false
        
      # Filter members based on requested channel
      if member.voiceChannel.name is not reqChannel
        return false
      # Otherwise return
      return true
    
    nicknames = members.map (member) ->
      return member.nickname
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
