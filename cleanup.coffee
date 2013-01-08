knox = require 'knox'
fs = require 'fs'
findit = require 'findit'
os = require 'os'
uuid = require 'node-uuid'
hostname = os.hostname
targetPath = process.argv[2]

d = new Date
s3Path = "/#{d.getUTCFullYear()}/#{d.getUTCMonth() + 1}/#{d.getUTCDate()}/#{d.toISOString()}_#{hostname}_#{uuid.v4().slice(0,8)}.json"


if process.argv.length == 4
  opts = fs.readFileSync process.argv[3]
  opts = JSON.parse opts
  console.log opts
else
  opts =
    key: process.argv[3]
    secret: process.argv[4]
    bucket: process.argv[5]

client = knox.createClient opts

files = findit.find targetPath

files.on 'file', (path) ->
  do (path) ->
    return unless path.match('s3logger.+Z')
    console.log "Shipping #{path}"
    client.putFile path, s3Path, (err, res) ->
      return console.log err if err
      console.log "Shipped #{path}"
      fs.unlink path, (err) ->
        console.log err if err
