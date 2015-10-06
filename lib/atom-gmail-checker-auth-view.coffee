{View, $} = require 'atom-space-pen-views'
URL = require "url"
module.exports =
class AtomGmailCheckerAuthView extends View
  @content: (params, self)->
    url = "#{params.src.replace(/"/g, '&quot;')}"
    @div id:"atomGmailCheckerBrowser", class:"browser", style:"height:100%;width:0px", =>
      @div class:"buttonOuter", =>
        @button "Close to Authentication for AtomGmailChecker.", outlet:"close", class: "btn", style: "float:right"
      @tag "webview", id:"auth", class:"auth native-key-bindings", outlet:"auth", src:"#{url}"

  attached: (onDom) ->
    @auth[0].addEventListener 'did-finish-load', (evt) =>
      url = URL.parse evt.path[0].src
      if /access_token=(.*?)&/.test(url.hash)
        @self.auth()
      else
        $("#atomGmailCheckerBrowser").width("450px")

  initialize: (params, self)->
    @self = self
    @close.on 'click', (evt) =>
      @self.panelHide()
