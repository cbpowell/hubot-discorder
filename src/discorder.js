/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
// Description:
//   A Hubot script to track users on a Discord server, nicknamed Mumbot
//
// Dependencies:
//   Discord.js
//
// Configuration:
//   HUBOT_DISCORDER_NICK - Username for Mumbot on the Mumble server
//   HUBOT_DISCORDER_TOKEN - Discord app token for bot-type
//   HUBOT_DISCORDER_GUILD - Discord guild ID to listen on
//   HUBOT_DISCORDER_ANNOUNCE_ROOMS - Rooms to make announcements in
//   HUBOT_DISCORDER_SHOULD_ANNOUNCE_ROOM_CHANGES - (True/False) Specifies if room changes should be announced. The first voice channel join will always be announced.
//   HUBOT_DISCORDER_ANNOUNCE_HIDDEN_ROOMS - Defines if robot should announce updates for rooms/channels that it does not have permission to enter (i.e. private rooms that the bot is not role'd to access). Defaults to false.
//
// Commands:
//   mumble me - List users on Discord, in all channels
//   who's online? - List users on Discord, in all channels
//   anyone online - List users on Discord, in all channels
//   anyone in/on <channel>? - Lists users on Discord, in specified channel
//   who's in/on <channel>? - Lists users on Discord, in specified channel
//
// Author:
//   cbpowell

const Url = require('url');
const Discord = require('discord.js');

String.prototype.strip = function() {
  if (String.prototype.trim != null) { return this.trim(); } else { return this.replace(/^\s+|\s+$/g, ""); }
};
  
const create_quiet_username = function(username) {
  const quietUsername = [];
  for (var x of Array.from(username)) {
    quietUsername.push(x);
    quietUsername.push("\u200B");
  }
  
  return quietUsername.join("");
};
  
const getAllIndexes = function(arr, val) {
  const indexes = [];
  let i = 0;
  while (i < arr.length) {
    if (arr[i] === val) {
      indexes.push(i);
    }
    i++;
  }
  return indexes;
};


module.exports = function(robot) {
  // Configure Mumble interface
  const options =
    {nick:     process.env.HUBOT_DISCORDER_NICK || robot.name};
  
  // Initiate Discord connection
  const mumbler = new Discord.Client({intents: ["GUILDS","GUILD_MESSAGES","GUILD_PRESENCES","GUILD_VOICE_STATES"]});
  
  const token = process.env.HUBOT_DISCORDER_TOKEN;
  
  mumbler.on("ready", () => console.log("Discord connection ready!"));
    
  mumbler.on("voiceStateUpdate", function(oldState, newState) {
    if ((newState == null)) {
      const logNick = oldState.member.displayName != null ? oldState.member.displayName : "[[Unknown]]";
      console.log(`Discorder: Update for ${logNick}: no newState object, assuming this was a part and ignoring`);
      return;
    }
  
    // Check if the user update is for joining a channel, not leaving
    if ((newState.channel == null)) {
      console.log(`Discorder: Update for ${newState.displayName}: moved to no-channel, assuming this was a part and ignoring`);
      return;
    }

    // Check if this is a channel change, return if not
    if (newState.channelId === oldState.channelId) {
      console.log(`Discorder: Update for ${newState.displayName}: change not related to voice channel, ignoring`);
      return;
    }
  
    // Check if the a channel change should be announced
    if (!process.env.HUBOT_DISCORDER_SHOULD_ANNOUNCE_ROOM_CHANGES) {
      if (oldState.channel != null) {
        // If the old member has a voice channel, this is not the initial join, do not announce
        console.log(`Discorder: Update for ${newState.displayName}: user has prior voice channel, and room change announce is set to OFF, ignoring`);
        return;
      }
    }

    const memberName = newState.member.displayName;
    const channelName = newState.channel.name;

    console.log("new Channel: ", newState.channel.viewable);

    // Filter updates about self
    if (memberName === options.nick) {
      console.log("Discorder: Update is about the robot itself, ignoring");
      return;
    }

    // Check for null username
    if (memberName === null) {
      console.log(`Discorder: Update for ${oldState.displayName}: update member name is null, ignoring`);
      return;
    }
  
    // Check if room is viewable to robot
    const announceUnviewable = process.env.HUBOT_DISCORDER_ANNOUNCE_HIDDEN_ROOMS != null ? process.env.HUBOT_DISCORDER_ANNOUNCE_HIDDEN_ROOMS : false;
    if (!announceUnviewable && !newState.channel.viewable) {
      console.log(`Discorder: new channel for ${newState.displayName} is unviewable to robot, ignoring`);
      return;
    }

    // Update room(s)
    const quietName = create_quiet_username(memberName);
    console.log(`Discorder: Update for ${memberName}: created quiet name (${quietName}), announcing`);
    const message = `🎮 ${quietName} moved into ${channelName}`;
    return robot.messageRoom(process.env.HUBOT_DISCORDER_ANNOUNCE_ROOMS, message);
  });
  
  mumbler.on("disconnect", event => console.log("Discord has disconnected."));
    
  mumbler.on("reconnecting", event => console.log("Discord is attempting to reconnect."));
    
  mumbler.on("error", function(error) {
    if (error.message != null) {
      return console.log(`Discord error: ${error.message}`);
    }
  });
  
  // Login
  mumbler.login(token);
  
  robot.hear(/(mumble me$)|(discord me$)|(who'?s online\?)|(anyone ((online)|(on mumble)|(on discord))\??)/i, function(msg) {
    // Get guild
    let message;
    const guild = mumbler.guilds.cache.first;
    
    if ((guild == null)) {
      console.log("Failed to find any guild in cache");
    }

    if (guild.id === !process.env.HUBOT_DISCORDER_GUILD) {
      console.log(`Wrong guild! ${guild.name}`);
      return;
    }
      
    // Get members
    const allMembers = guild.members.fetch();
    const ignored = [options.nick];
    // Filter members based on ignored, and connected status
    const members = allMembers.filter(function(member) {
      if (Array.from(ignored).includes(member.nickname) || Array.from(ignored).includes(member.user.username)) {
        return false;
      }
      if ((member.voice.channel == null)) {
        return false;
      }
      return true;
    });
    
    const nicknames = members.map(member => member.displayName);
    const channels = members.map(member => member.voiceChannel.name);
    
    //console.log "Nicknames: #{nicknames}"
    //console.log "Channels: #{channels}"
    
    const uniqueChannels = channels.filter((x, i, a) => a.indexOf(x) === i);
    
    if (members.length === 0) {
      message = "No one on Discord 😕";
    } else {
      message = "🎮 Online:";
      for (var id in uniqueChannels) {
        var chan = uniqueChannels[id];
        var idxs = getAllIndexes(channels, chan);
        message = message + ` [${chan}] `;
        for (var idx of Array.from(idxs)) {
          if (nicknames[idx] != null) {
            var u = create_quiet_username(nicknames[idx]);
            message = message + `${u}, `;
          }
        }
      
        
        message = message.substring(0, message.length - 2);
      }
    }
        
    return msg.send(message);
  });
    
  return robot.hear(/(?:mumble me (.+))|(?:(?:anyone|who'?s) (?:in|on) (.+)\?)/i, function(msg) {
    let channels, members, message, nicknames;
    const reqChannel = msg.match[1] || msg.match[2];
    if ((typeof channel === 'undefined' || channel === null)) {
      msg.send("Not a valid channel 😬");
      return;
    
      // Get guild
      const guild = mumbler.guilds.cache.first;
    
      if ((guild == null)) {
        console.log("Failed to find any guild in cache");
      }

      if (guild.id === !process.env.HUBOT_DISCORDER_GUILD) {
        console.log(`Wrong guild! ${guild.name}`);
        return;
      }
      
      // Get members
      const allMembers = guild.members.fetch();
      const ignored = [options.nick];
      // Filter members based on ignored, and connected status
      members = allMembers.filter(function(member) {
        if (Array.from(ignored).includes(member.nickname) || Array.from(ignored).includes(member.user.username)) {
          return false;
        }
        if ((member.voice.channel == null)) {
          return false;
        }
        return true;
      });
    
      nicknames = members.map(member => member.displayName);
      channels = members.map(member => member.voiceChannel.name);
    }
    
    //console.log "Nicknames: #{nicknames}"
    //console.log "Channels: #{channels}"
    
    if (members.length === 0) {
      message = `No one in ${reqChannel} 😕`;
    } else {
      message = `🎮 Online in ${reqChannel}:`;
      for (var id in channels) {
        var chan = channels[id];
        var idxs = getAllIndexes(channels, chan);
        message = message + ` [${chan}] `;
        for (var idx of Array.from(idxs)) {
          var u = create_quiet_username(nicknames[idx]);
          message = message + `${u}, `;
        }
      }
      
      message = message.substring(0, message.length - 2);
    }
    return msg.send(message);
  });
};
