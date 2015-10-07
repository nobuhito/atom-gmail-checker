AtomGmailCheckerAuthView = require './atom-gmail-checker-auth-view'
AtomGmailCheckerStatusView = require './atom-gmail-checker-status-view'
AtomGmailCheckerPreviewView = require "./atom-gmail-checker-preview-view"
{CompositeDisposable} = require 'atom'

fs = require 'fs'
path = require 'path'
_ = require "underscore-plus"
http = require "https"

API = "https://www.googleapis.com"

module.exports = AtomGmailChecker =
  authPanel: null
  counter: null
  statusBar: null
  statusBarTile: null
  preview: null
  previewPanel: null
  isLogin: false

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

  toggleCommand: ->
    @subscriptions = null
    if @isLogin
      @subscriptions = new CompositeDisposable
      @subscriptions.add atom.commands.add 'atom-workspace',
        'atom_gmail_checker:logout': => @logout()
    else
      @subscriptions = new CompositeDisposable
      @subscriptions.add atom.commands.add 'atom-workspace',
        'atom_gmail_checker:login': => @auth()

  activate: (state) ->

    @SCOPES = ["#{API}/auth/gmail.readonly"]
    @counter = new AtomGmailCheckerStatusView({userId: ""})
    @toggleCommand()

  consumeStatusBar: (statusBar) ->
    @statusBarTile = statusBar.addRightTile
      item: atom.views.getView(@counter), priority: -1
    @start()

  start: ->
    console.log "gmail-checker was start."
    @auth()

  auth: ->
    clearInterval(@unreadCheckTimer) if @unreadCheckTimer
    params = {}
    params.src = "https://nobuhito.github.io/atom-gmail-checker/oauth2callback#auth"

    auth = new AtomGmailCheckerAuthView(params, this)
    @authPanel = atom.workspace.addRightPanel(item: atom.views.getView(auth))

  setReAuth: (interval) ->
    @authTimer = setInterval =>
      @auth()
    , interval

  postAuth: (access_token) ->
    @access_token = access_token
    setTimeout =>
      @panelHide()
    , 5000
    @setUserId() unless @emailAddress?

  setUserId: ->
    url = "#{API}/gmail/v1/users/me/profile?access_token=#{@access_token}"
    @getJson url, (err, res) =>
      return null if err
      @isLogin = true
      @toggleCommand()
      @counter.setHistoryId res.historyId
      @counter.setEmailAddress res.emailAddress
      @emailAddress = res.emailAddress
      @getUnread @counter, res.emailAddress

  getUnread: (emailAddress) ->
    @preview = new AtomGmailCheckerPreviewView({userId: emailAddress})
    @preview.hide()
    @previewPanel = atom.workspace.addBottomPanel(item: atom.views.getView(@preview))

    _setUnread = (counter, preview, res) ->
      counter.setUnreadCount (res.threads?.length || 0)
      return null unless res.threads?

      previewTime = atom.config.get("atom-gmail-checker.previewTime") * 1000
      threads = res.threads.filter (d) => d.historyId > counter.getHistoryId()

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

    options = [
      "access_token=#{@access_token}",
      "maxResults=50",
      "q=#{encodeURIComponent(atom.config.get("atom-gmail-checker.checkQuery"))}"
    ]
    url = "#{API}/gmail/v1/users/me/threads?#{options.join("&")}"
    @getJson url, (err, res) =>
      return null if err
      _setUnread @counter, @preview, res
    interval = atom.config.get("atom-gmail-checker.checkInterval") * 1000
    @unreadCheckTimer = setInterval (() =>
      @counter.setUnreadCount "*"
      @getJson url, (err, res) =>
        return null if err
        _setUnread @counter, @preview, res
    ), interval

  logout: ->
    localStorage.removeItem("atom_gmail_checker_token")
    params = {
      src: "http://mail.google.com/mail/?logout"
    }
    auth = new AtomGmailCheckerAuthView(params, this)
    @authPanel = atom.workspace.addRightPanel(item: atom.views.getView(auth))
    @isLogin = false
    @toggleCommand()

  getJson: (url, cb) ->
    req = http.get url, (res) =>
      if res.statusCode is 200
        body = ""
        res.on "data", (chunk) =>
          body += chunk
        res.on "end", () =>
          res = JSON.parse(body)
          cb null, res
      else
        message = "#{res.statusCode}:#{res.statusMessage} (#{res.req._header})"
        console.error res
        atom.notifications.addError("Atom gmail checker error", {detail: message, dismissable: true})
        cb message, null
    req.on "error", (e) =>
      console.log url
      console.error e
      atom.notifications.addError("Atom gmail checker error", {detail: JSON.stringify(e), dismissable: true})
      cb e, null

  panelHide: ->
    @authPanel.hide()
    @authPane = null

  deactivate: ->
    @dispose()
    @subscriptions?.dispose()

  dispose: ->
    clearInterval(@unreadCheckTimer) if @unreadCheckTimer
    clearInterval(@authTimer) if @authTimer
    @authPanel = null
    @statusBarTile?.destroy()
    @tatusBarTile = null
