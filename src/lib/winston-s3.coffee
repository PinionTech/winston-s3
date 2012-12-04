knox = require 'knox'
winston = require 'winston'
TempFile = require 'temporary/file'
module.exports =
class winston.transports.S3 extends winston.Transport
  name: 's3'

  constructor: (opts={}) ->
    super

    @client = knox.createClient key: opts.key,
                                secret: opts.secret,
                                bucket: opts.bucket
    @bufferSize = 0
    @maxSize = opts.maxSize || 20 * 1024 * 1024

  log: (level, msg='', meta, cb) ->
    cb null, true if @silent

  timeForNewLog: ->
    (@maxSize and @bufferSize >= @maxSize) and
      (@maxTime and @openedAt and new Date - @openedAt > @maxTime)

  open: (cb) ->
    if @opening
      cb true
    else if (!@_stream or @maxSize and @bufferSize >= @maxSize)
      cb true
      @_createStream()
    else
      cb()

  shipIt: ->
    @client.putFile @_stream.path, @_s3Path(), (err, res) ->
      console.log err if err

  _s3Path: ->
    d = new Date
    "/#{d.getUTCFullYear}/#{d.getUTCMonth}/#{d.getUTCDate}/#{d.getUTCHours}_#{d.getUTCMinutes}.json"

  _createStream: ->
    @opening = true
    if @_stream
      @_stream.close() ->
        @shipIt()
      @_stream.destroySoon()

    @bufferSize = size
    @_stream = new Tempfile
    @opening = false
    #
    # We need to listen for drain events when
    # write() returns false. This can make node
    # mad at times.
    #
    @_stream.setMaxListeners Infinity
    #
    # When the current stream has finished flushing
    # then we can be sure we have finished opening
    # and thus can emit the `open` event.
    #
    @once "flush", ->
      @opening = false
      @emit "open", @_stream.path

    #
    # Remark: It is possible that in the time it has taken to find the
    # next logfile to be written more data than `maxsize` has been buffered,
    # but for sensible limits (10s - 100s of MB) this seems unlikely in less
    # than one second.
    #
      @flush()

