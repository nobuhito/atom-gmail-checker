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

    @SCOPES = ["#{API}/auth/gmail.readonly"]
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
    unless localStorage.atom_gmail_checker_token?
      params = [
        "response_type=token",
        "scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.readonly",
        "redirect_uri=https%3A%2F%2Fscript.google.com%2Fmacros%2Fs%2FAKfycbyG6U0qbd2uV1iGa-7dH3qeqY1VRZKppcbGvYZMBMHL0_IzE_7F%2Fexec",
        "client_id=694137224755-obduaqe092fre3cpa69bfd41qhl0of2n",
      ]
      params.src = "https://accounts.google.com/o/oauth2/auth?&#{params.join("&")}"

      auth = new AtomGmailCheckerAuthView(params, this)
      @authPanel = atom.workspace.addRightPanel(item: atom.views.getView(auth))
    else
      @setUserId()

  auth: ->
    localStorage.atom_gmail_checker_token = RegExp.$1
    @panelHide()
    @setUserId()

  setUserId: ->
    url = "#{API}/gmail/v1/users/me/profile?access_token=#{localStorage.atom_gmail_checker_token}"
    @getJson url, (res) =>
      @subscriptions = new CompositeDisposable
      @subscriptions.add atom.commands.add 'atom-workspace',
        'atom_gmail_checker:logout': => @logout()
      @counter.setHistoryId res.historyId
      @counter.setEmailAddress res.emailAddress
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
      "access_token=#{localStorage.atom_gmail_checker_token}",
      "maxResults=50",
      "q=#{encodeURIComponent(atom.config.get("atom-gmail-checker.checkQuery"))}"
    ]
    url = "#{API}/gmail/v1/users/me/threads?#{options.join("&")}"
    @getJson url, (res) =>
      _setUnread @counter, @preview, res
    interval = atom.config.get("atom-gmail-checker.checkInterval") * 1000
    timer = setInterval (() =>
      @counter.setUnreadCount "*"
      @getJson url, (res) =>
        _setUnread @counter, @preview, res
    ), interval

    @counter.setIntervalNumber timer

  logout: ->
    localStorage.removeItem("atom_gmail_checker_token")
    params = {
      src: "http://mail.google.com/mail/?logout"
    }
    auth = new AtomGmailCheckerAuthView(params, this)
    @authPanel = atom.workspace.addRightPanel(item: atom.views.getView(auth))

  getJson: (url, cb) ->
    req = http.get url, (res) =>
      body = ""
      res.on "data", (chunk) =>
        body += chunk
      res.on "end", () =>
        res = JSON.parse(body)
        cb(res)
    req.on "error", (e) =>
      console.log e

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
