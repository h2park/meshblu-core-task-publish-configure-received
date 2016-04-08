_ = require 'lodash'
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
    {toUuid} = request.metadata
    message = JSON.stringify @_buildMessage request
    @_send {toUuid, message}, (error) =>
      return callback error if error?
      return @_doCallback request, 204, callback

  _buildMessage: (request) =>
    return {
      metadata:
        route: request.metadata.route
      rawData: request.rawData
    }

  _send: ({toUuid, message}, callback=->) =>
    @uuidAliasResolver.resolve toUuid, (error, uuid) =>
      return callback error if error?
      @cache.publish "#{uuid}", message, callback

module.exports = PublishConfigureReceived
