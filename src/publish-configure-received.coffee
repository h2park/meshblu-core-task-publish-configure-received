_    = require 'lodash'
http = require 'http'

class PublishConfigureReceived
  constructor: (options={}) ->
    {@cache,@uuidAliasResolver} = options

  _doCallback: (request, code, callback) =>
    response =
      metadata:
        responseId: request.metadata.responseId
        code: code
        status: http.STATUS_CODES[code]
    callback null, response

  do: (request, callback) =>
    {fromUuid, toUuid, route} = request.metadata
    lastHop = _.last route
    return @_doCallback request, 422, callback unless fromUuid?
    return @_doCallback request, 422, callback unless toUuid?
    return @_doCallback request, 422, callback unless lastHop?
    return @_doCallback request, 204, callback unless lastHop.from == lastHop.to && lastHop.type == 'configure.received'

    @uuidAliasResolver.resolve toUuid, (error, toUuid) =>
      return callback error if error?

      message = JSON.stringify @_buildMessage request
      @_send {toUuid, message}, (error) =>
        return callback error if error?
        return @_doCallback request, 204, callback

  _buildMessage: (request) =>
    return {
      metadata:
        responseId: request.metadata.responseId
        route: request.metadata.route
        forwardedRoutes: request.metadata.forwardedRoutes
      rawData: request.rawData
    }

  _send: ({toUuid, message}, callback=->) =>
    @cache.publish "#{toUuid}", message, callback

module.exports = PublishConfigureReceived
