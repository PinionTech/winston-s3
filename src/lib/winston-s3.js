var coffee = require('coffee-script');
if (typeof coffee.register !== 'undefined') coffee.register();
return require('./winston-s3.coffee');
