_ = require 'lodash'
uuid = require 'uuid'
redis = require 'fakeredis'
PublishConfigureReceived = require '..'

describe 'PublishConfigureReceived', ->
  beforeEach ->
    @redisKey = uuid.v1()
    @uuidAliasResolver = resolve: sinon.stub().yields null, 'receiver-uuid'
    options = {
      cache: redis.createClient(@redisKey)
      @uuidAliasResolver
    }

    dependencies = {@request}

    @sut = new PublishConfigureReceived options, dependencies
    @cache = redis.createClient @redisKey

  describe '->do', ->
    context 'when given a valid message', ->
      beforeEach (done) ->
        @cache.subscribe 'receiver-uuid', (error) => done error

      beforeEach (done) ->
        request =
          metadata:
            responseId: 'its-electric'
            auth:
              uuid: 'receiver-uuid'
              token: 'receiver-token'
            toUuid: 'receiver-uuid'
            fromUuid: 'receiver-uuid'
            route: [
              {type: 'configure.sent',     from: 'sender-uuid',   to: 'receiver-uuid'}
              {type: 'configure.received', from: 'receiver-uuid', to: 'receiver-uuid'}
            ]
          rawData: '{"does_not":"matter"}'

        doneTwice = _.after 2, done
        @cache.once 'message', (channel, @message) => doneTwice()
        @sut.do request, (error, @response) => doneTwice error

      it 'should return a 204', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 204
            status: 'No Content'

        expect(@response).to.deep.equal expectedResponse

      it 'should publish the message to redis', ->
        expect(@message).to.exist
        expect(JSON.parse @message).to.deep.equal {
          metadata:
            responseId: 'its-electric'
            route: [
              {type: 'configure.sent',     from: 'sender-uuid',   to: 'receiver-uuid'}
              {type: 'configure.received', from: 'receiver-uuid', to: 'receiver-uuid'}
            ]
          rawData: '{"does_not":"matter"}'
        }

    context 'when given a valid message with an alias', ->
      beforeEach (done) ->
        @cache.subscribe 'receiver-uuid', (error) =>
          done error

      beforeEach (done) ->
        request =
          metadata:
            responseId: 'its-electric'
            auth:
              uuid: 'sender-uuid'
              token: 'sender-token'
            toUuid: 'muggle-mouth'
            fromUuid: 'sender-uuid'
            route: [
              {type: 'configure.sent',     from: 'sender-uuid', to: 'receiver-uuid'}
              {type: 'configure.received', from: 'receiver-uuid', to: 'receiver-uuid'}
            ]
            messageType: 'sent'
          rawData: '{"does_not":"matter"}'
        @uuidAliasResolver.resolve.yields null, 'receiver-uuid'

        doneTwice = _.after 2, done
        @cache.once 'message', (channel, @message) => doneTwice()
        @sut.do request, (error, @response) => doneTwice error

      it 'should return a 204', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 204
            status: 'No Content'

        expect(@response).to.deep.equal expectedResponse

      it 'should publish the message to redis', ->
        expect(@message).to.exist
        expect(JSON.parse @message).to.deep.equal {
          metadata:
            responseId: 'its-electric'
            route: [
              {type: 'configure.sent',     from: 'sender-uuid',   to: 'receiver-uuid'}
              {type: 'configure.received', from: 'receiver-uuid', to: 'receiver-uuid'}
            ]
          rawData: '{"does_not":"matter"}'
        }

    context 'when given a valid config not from me to me in the last hop', ->
      beforeEach (done) ->
        @cache.subscribe 'receiver-uuid', (error) => done error

      beforeEach (done) ->
        request =
          metadata:
            responseId: 'its-electric'
            auth:
              uuid: 'receiver-uuid'
              token: 'receiver-token'
            toUuid: 'receiver-uuid'
            fromUuid: 'other-uuid'
            route: [
              {type: 'config.received', from: 'sender-uuid', to: 'receiver-uuid'}
            ]

          rawData: '{"does_not":"matter"}'

        @cache.once 'message', (channel, @message) => throw new Error('Should not publish this config')
        @sut.do request, (error, @response) => done error

      it 'should return a 204', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 204
            status: 'No Content'

        expect(@response).to.deep.equal expectedResponse

      it 'should not publish the message to redis', (done) ->
        _.defer =>
          expect(@message).not.to.exist
          done()
        , 100
