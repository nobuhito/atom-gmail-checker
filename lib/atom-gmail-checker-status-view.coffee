{View, $} = require 'atom-space-pen-views'
module.exports =
class AtomGmailCheckerStatusView extends View
  @content: (params)->
    c = "atom-gmail-checker"
    title = "Click to open web browser."
    @a class: "#{c} loginlink", title: title, href:"http://mail.google.com/", =>
      @div class: "#{c} inline-block icon-mail", =>
        @span " "
        @span "-", class: "#{c} counter", outlet: "counter"

  setEmailAddress: (email) ->
    q = encodeURIComponent(atom.config.get("atom-gmail-checker.checkQuery"))
    el = document.querySelector(".atom-gmail-checker.loginlink")
    $(el).attr("href", "https://mail.google.com/mail/u/#{email}/#search/#{q}")

  setUnreadCount: (num) ->
    @counter.text num

  setHistoryId: (id) ->
    @counter.attr "data-historyId", id

  getHistoryId: ->
    @counter.attr "data-historyId"
