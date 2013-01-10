knox = require 'knox'
winston = require 'winston'
fs = require 'fs'
uuid = require 'node-uuid'
findit = require 'findit'
path = require 'path'
fork = require('child_process').fork
TempFile = () ->
  return fs.createWriteStream path.join @_path, 's3logs', 's3logger_' + new Date().toISOString()
module.exports =
class winston.transports.S3 extends winston.Transport
  name: 's3'

  constructor: (opts={}) ->
    super

    fs.mkdir path.join(__dirname, 's3logs'), 0o0770, (err) =>
      return if err.code == 'EEXIST' if err?
      console.log err if err

    @client = knox.createClient {
      key: opts.key
      secret: opts.secret
      bucket: opts.bucket
    }
    @bufferSize = 0
    @maxSize = opts.maxSize || 20 * 1024 * 1024
    @_id = opts.id || (require 'os').hostname
    @_nested = opts.nested || false
    @_path = opts.path || __dirname

  log: (level, msg='', meta, cb) ->
    cb null, true if @silent
    if @_nested
      item =
        level: level
        msg: msg
        time: new Date().toISOString()
        id: @_id
    else
      msg = {msg: msg} if typeof msg =='string'
      item = msg
      item.s3_level = level
      item.s3_time = new Date().toISOString()
      item.s3_id = @_id

    item = JSON.stringify(item) + '\n'

    @open (newFileRequired) =>
      @bufferSize += item.length
      @_stream.write item
      this.emit "logged"
      cb null, true

  timeForNewLog: ->
    (@maxSize and @bufferSize >= @maxSize) and
      (@maxTime and @openedAt and new Date - @openedAt > @maxTime)

  open: (cb) ->
    if @opening
      cb true
    else if (!@_stream or @maxSize and @bufferSize >= @maxSize)
      @_createStream(cb)
      cb true
    else
      cb()

  shipIt: (path) ->
    @shipQueue = {} if @shipQueue == undefined
    return if @shipQueue[path]?
    @shipQueue[path] = path
    @client.putFile path, @_s3Path(), (err, res) =>
      return console.log err if err
      return console.log "S3 error, code #{res.statusCode}" if res.statusCode != 200
      delete @shipQueue[path]
      fs.unlink path, (err) ->
        console.log err if err

  _s3Path: ->
    d = new Date
    "/#{d.getUTCFullYear()}/#{d.getUTCMonth() + 1}/#{d.getUTCDate()}/#{d.toISOString()}_#{@_id}_#{uuid.v4().slice(0,8)}.json"

  checkUnshipped: ->
    unshippedFiles = findit.find path.join __dirname, 's3logs'
    unshippedFiles.on 'file', (path) =>
      do (path) =>
        return unless path.match 's3logger.+Z'
        if @_stream
          return if path == @_stream.path
        @shipIt path

  _createStream: ->
    @checkUnshipped()
    @opening = true
    if @_stream
      stream = @_stream
      stream.end()
      stream.on 'close', =>
        @shipIt(stream.path)
      stream.on 'drain', ->
      stream.destroySoon()

    @bufferSize = 0
    @_stream = new TempFile
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
