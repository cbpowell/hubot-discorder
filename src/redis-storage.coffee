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
  
  # Uniformly and unambiguously convert an array of Strings and nulls into a valid
  # Redis key. Uses a length-prefixed encoding.
  #
  # _encode([null, null, "a"]) = "markov:001a"
  # _encode(["a", "bb", "ccc"]) = "markov:1a2b3c"
  _encode: (user, key) ->
    encoded = for part in key
      if part then "#{part.length}#{part}" else "0"
    user + "_" + keyprefix + encoded.join('')

  # Record a transition within the model. "transition.from" is an array of Strings and
  # nulls marking the prior state and "transition.to" is the observed next state, which
  # may be an end-of-chain sentinel.
  increment: (user, transition) ->
    @client.hincrby(@._encode(user, transition.from), transition.to, 1)

  # Retrieve an object containing the possible next hops from a prior state and their
  # relative frequencies. Invokes "callback" with the object.
  get: (user, prior, callback) ->
    @client.hgetall @._encode(user, prior), (err, hash) ->
      throw err if err
      callback(hash)

module.exports = RedisStorage
