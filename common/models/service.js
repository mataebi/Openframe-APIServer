var loopback = require('loopback'),
    // loopbackCtx = require('loopback-context'),
    path = require('path'),
    debug = require('debug')('openframe:model:Service');

module.exports = function(Service) {

    // Get configuration via REST endpoint
    Service.cfg = function(cb) {
        var config = {
            pubsub_url: Service.app.get('ps_url')
        };
        cb(null, config);
    };

    // Expose config remote method
    Service.remoteMethod(
        'cfg', {
            description: 'Get some general config info from the API server.',
            accepts: [],
            http: {
                verb: 'get',
            },
            returns: {
                arg: 'config',
                type: 'object'
            }
        }
    );
};
