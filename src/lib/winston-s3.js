var coffee = require('coffee-script');
if (typeof coffee.register !== 'undefined') coffee.register();
var ws3 = require('./winston-s3.coffee');
module.exports = ws3;
return ws3;
