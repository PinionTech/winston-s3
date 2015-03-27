winston-s3
===============

A full featured S3 transport for winston

## Install

```bash
npm i -S winston winston-s3
```

## Setup

```js
var winston = require('winston')
  , winstonS3 = require('winston-s3')

winston.add(winstonS3, {
  key: 's3-key'
  , secret: 's3-secret'
  , bucket: 'bucket-name'
  
  // optional
  , maxSize: 20 * 1024 * 1024 // default
  , id: '' // defaults to the hostname
  , nested: false
  , path: // defaults to 's3Logs'
  , temp: false
  , debug: false
  , headers: {} //headers that will be passed along to knox for the http requests
})

```
