class RedisStorage

  # Prefix used to isolate stored Mumble status in the database
  keyprefix = "mumble:"

  # Create a storage module that uses the provided Redis connection.
  constructor: (@client) ->
    
  onlineUsers: (ignored, callback) ->
    @client.hgetall keyprefix + 'users', (err, users) =>
      userNames = []
      chanIds = []
      channels = {}
      for user, chanId of users
        if user not in ignored
          userNames.push user
          chanIds.push chanId
      
      if chanIds.length > 0
        @.channelNamesForIds chanIds, (err, channelNames) ->
          for chanName, ind in channelNames
            users[userNames[ind]] = chanName
            (channels[chanName] or= []).push userNames[ind]
          
          callback(userNames,channels)
            
      else
        callback(userNames,channels)
  
  updateUsers: (users) ->
    # Clear users
    @.clearUsers
    # Update users
    for k,u of users
      @.updateUser(u.name, u.channel.id)
  
  updateUser: (userName, location) ->
    @client.hset keyprefix + 'users', userName, location
    
  removeUser: (userName) ->
    @client.hdel keyprefix + 'users', userName
  
  locationsForUsers: (userNames, callback) ->
    @client.hget keyprefix + 'users', userNames, callback
  
  channelForUser: (userName) ->
    channelId = @.locationForUser(userName)
    return @.channelNameForId(channelId)
  
  clearUsers: ->
    @client.del(keyprefix + 'users')
    
  updateChannels: (channels) ->
    for k,c of channels
      @.updateChannel c.channelId, c.name
  
  updateChannel: (id, channel) ->
    @client.hset(keyprefix + 'channels', id, channel)
  
  channelNamesForIds: (ids, callback) ->
    @client.hmget keyprefix + 'channels', ids, callback
  
  clearChannels: ->
    @client.del(keyprefix + 'channels')

module.exports = RedisStorage