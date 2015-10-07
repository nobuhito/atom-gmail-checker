{View, $} = require 'atom-space-pen-views'
URL = require "url"
module.exports =
class AtomGmailCheckerAuthView extends View
  @content: (params, self)->
    url = "#{params.src.replace(/"/g, '&quot;')}"
    @div id:"atomGmailCheckerBrowser", class:"browser", style:"height:100%;width:0px", =>
      @div class:"buttonOuter inline-block", =>
        @button "Close to Authentication for AtomGmailChecker.", outlet:"close", class: "btn", style: "float:right"
      @tag "webview", id:"auth", class:"auth native-key-bindings", outlet:"auth", src:"#{url}"

  attached: (onDom) ->
    @auth[0].addEventListener 'did-finish-load', (evt) =>
      url = URL.parse evt.path[0].src
      hashes = {}

      if url.hash?
        for item in url.hash.replace(/^#/, "").split("&")
          hash = item.split("=")
          hashes[hash[0]] = hash[1]

        if hashes.access_token? and hashes.expires_in?
          @self.setReAuth hashes.expires_in * 1000
          @self.postAuth hashes.access_token
          return null

      $("#atomGmailCheckerBrowser").width("450px")

  initialize: (params, self)->
    @self = self
    @close.on 'click', (evt) =>
      @self.panelHide()
