require('dotenv').config { silent: true }

express            = require 'express'
morgan             = require 'morgan'
bodyParser         = require 'body-parser'
cors               = require 'cors'
MeshbluHttp        = require 'meshblu-http'
OctobluRaven       = require 'octoblu-raven'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
packageVersion     = require 'express-package-version'
sendError          = require 'express-send-error'
Routes             = require './app/routes'
{DeviceAuthenticator} = require 'meshblu-authenticator-core'

try
  meshbluJSON  = require './meshblu.json'
catch
  meshbluJSON =
    uuid:   process.env.MESHBLU_UUID
    token:  process.env.MESHBLU_TOKEN
    protocol: process.env.MESHBLU_PROTOCOL
    hostname: process.env.MESHBLU_HOSTNAME
    port:   process.env.MESHBLU_PORT

meshbluJSON.name = process.env.EMAIL_PASSWORD_AUTHENTICATOR_NAME ? 'Email Authenticator'

port = process.env.EMAIL_PASSWORD_AUTHENTICATOR_PORT ? process.env.PORT ? 80
forwarderUrl = process.env.FORWARDER_URL

octobluRaven = new OctobluRaven()
octobluRaven.patchGlobal()

app = express()
app.use octobluRaven.express().handleErrors()
app.use sendError()
app.use cors()

app.use meshbluHealthcheck()
app.use packageVersion()

app.use morgan 'dev', immediate: false unless @disableLogging
app.use bodyParser.json()
app.use bodyParser.urlencoded(extended: true)
app.use cors()

meshbluHttp = new MeshbluHttp meshbluJSON

authenticatorUuid = meshbluJSON.uuid
authenticatorName = meshbluJSON.name

deviceModel = new DeviceAuthenticator {authenticatorUuid, authenticatorName, meshbluHttp}

meshbluHttp.device meshbluJSON.uuid, (error, device) ->
  if error?
    console.error error.message, error.stack
    process.exit 1

  unless device.privateKey?
    console.error 'meshblu-authenticator-email-password requires privateKey'
    process.exit 1

  meshbluHttp.setPrivateKey device.privateKey

  app.listen port, =>
    console.log "listening at localhost:#{port}"

routes = new Routes {app, meshbluHttp, deviceModel, forwarderUrl}
routes.register()


process.on 'SIGTERM', =>
  console.log 'SIGTERM caught, exiting'
  process.exit 0
