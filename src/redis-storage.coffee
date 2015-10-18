class RedisStorage

  # Prefix used to isolate stored Mumble status in the database
  keyprefix = "mumble:"

  # Create a storage module that uses the provided Redis connection.
  constructor: (@client) ->
    
  onlineUsers: (ignored, callback) ->
    @client.hgetall keyprefix + 'users', (err, users) =>
      userNames = []
      chanIds = []
      for user, chanId of users
        if user not in ignored
          userNames.push user
          chanIds.push chanId
      
      unless chanIds.length is 0
        channels = {}
        @.channelNamesForIds chanIds, (err, channelNames) ->
          channels = {}
          for chanName, ind in channelNames
            users[userNames[ind]] = chanName
            (channels[chanName] or= []).push userNames[ind]
        
      callback(users,channels)
  
  updateUsers: (users) ->
    for k,u of users
      @.updateUser(u.name, u.channelId)
  
  updateUser: (userName, location = null) ->
    if location then @client.hset keyprefix + 'users', userName, location else @.removeUser(userName)
    
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
