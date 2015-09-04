AtomGmailCheckerAuthView = require './atom-gmail-checker-auth-view'
AtomGmailCheckerStatusView = require './atom-gmail-checker-status-view'
AtomGmailCheckerPreviewView = require "./atom-gmail-checker-preview-view"
{CompositeDisposable} = require 'atom'

fs = require 'fs'
path = require 'path'
_ = require "underscore-plus"

module.exports = AtomGmailChecker =
  authPanel: null
  counter: null
  statusBar: null
  statusBarTile: null
  preview: null
  previewPanel: null

  config:
    checkInterval:
      title: "Check interval (sec)"
      type: "integer"
      default: 60
    previewTime:
      title: "Preview time (sec)"
      type: "integer"
      default: 5
    checkQuery:
      title: "Check query"
      type: "string"
      default: "is:unread is:inbox"
    startupDelayTime:
      title: "Startup Delay time (sec)"
      type: "integer"
      default: 5

  activate: (state) ->

    @SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]
    @TOKEN_DIR = (process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE) + "/.atom/"
    @TOKEN_PATH = @TOKEN_DIR + "atom-gmail-checker-token.json"
    @CLIENT_SECRET = path.join(__dirname, "..", "client_secret.json")
    @counter = new AtomGmailCheckerStatusView({userId: ""})

  consumeStatusBar: (statusBar) ->
    @statusBarTile = statusBar.addRightTile
      item: atom.views.getView(@counter), priority: -1
    setTimeout =>
     @start()
    , atom.config.get("atom-gmail-checker.startupDelayTime") * 1000

  start: ->
    console.log "gmail-checker was start."
    fs.readFile @CLIENT_SECRET, (err, content) =>
      if err
        console.log "Error loading client secret file: #{err}"
        return
      @authorize JSON.parse(content), @getUnread

  authorize: (credentials, callback) ->
    googleAuth = require "google-auth-library"
    clientSecret = credentials.installed.client_secret
    clientId = credentials.installed.client_id
    redirectUrl = credentials.installed.redirect_uris[0]
    auth = new googleAuth
    oauth2Client = new auth.OAuth2 clientId, clientSecret, redirectUrl

    fs.readFile @TOKEN_PATH, (err, token) =>
      if err
        @getNewToken oauth2Client, callback
      else
        oauth2Client.credentials = JSON.parse token
        callback oauth2Client, @counter

  getNewToken: (oauth2Client, callback) ->
    params = {
      url: oauth2Client.generateAuthUrl({
        access_type: 'offline'
        scope: @SCOPES
      }),
      oauth2Client: oauth2Client,
      callback: callback
    }
    auth = new AtomGmailCheckerAuthView(params, this)

    @authPanel = atom.workspace.addModalPanel(item: atom.views.getView(auth))
    # auth.initialize(params, this)

  inputCode: (oauth2Client, code, callback) ->
    oauth2Client.getToken code, (err, token) =>
      if err
        console.log "Error while trying to retrieve access token: #{err}"
        return
      oauth2Client.credentials = token
      @storeToken token
      callback oauth2Client, @counter

  storeToken: (token) ->
    fs.writeFile(@TOKEN_PATH, JSON.stringify(token))
    console.log "Token stored to #{@TOKEN_PATH}"

  getUnread: (auth, counter) ->

    google = require "googleapis"
    gmail = google.gmail("v1")

    option = {
      auth: auth
      userId: 'me'
      includeSpamTrash: false
      maxResults: 50
      q: atom.config.get("atom-gmail-checker.checkQuery")
    }

    gmail.users.getProfile {userId: "me", auth: auth}, (err, response) =>
      console.log err if err
      counter.setEmailAddress response.emailAddress
      counter.setHistoryId response.historyId

      @preview = new AtomGmailCheckerPreviewView({userId: response.emailAddress})
      @preview.hide()
      @previewPanel = atom.workspace.addBottomPanel(item: atom.views.getView(@preview))

      option = {
        auth: auth
        userId: 'me'
        includeSpamTrash: false
        maxResults: 50
        q: atom.config.get("atom-gmail-checker.checkQuery")
      }

      _setUnread = (counter, preview, response) =>
        counter.setUnreadCount (response.threads?.length || 0)
        return null unless response.threads?

        previewTime = atom.config.get("atom-gmail-checker.previewTime") * 1000
        threads = response.threads.filter (d) => d.historyId > counter.getHistoryId()
        if threads.length > 0
          preview.show()
          for thread, i in threads
            setTimeout ((t) =>
              preview.setSnippet t.snippet
            ), previewTime * i, thread
          setTimeout =>
            preview.hide()
          , previewTime * threads.length
          counter.setHistoryId _.max(threads, (d)->d.historyId)

      gmail.users.threads.list option, (err, response) =>
        console.log err if err
        _setUnread counter, preview, response if response?

      interval = atom.config.get("atom-gmail-checker.checkInterval") * 1000
      timer = setInterval (() =>
        counter.setUnreadCount "*"
        gmail.users.threads.list option, (err, response) =>
          console.log err if err
          _setUnread counter, preview, response if response?
      ), interval

      counter.setIntervalNumber(timer)

  panelHide: ->
    @authPanel.hide()

  deactivate: ->
    @dispose()
    @subscriptions?.dispose()

  dispose: ->
    timer = @counter.getIntervalNumber("data-number")
    clearInterval(timer) if timer
    @authPanel = null
    @statusBarTile?.destroy()
    @tatusBarTile = null
