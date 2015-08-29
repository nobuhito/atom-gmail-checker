{View, TextEditorView} = require 'atom-space-pen-views'
module.exports =
class AtomGmailCheckerAuthView extends View
  @content: (params, self) ->

    @div class: "atom-gmail-checker", =>
      @h1 "Atom gmail checker"
      @div =>
        @div class: "inline-block", =>
          @h2 "1. Open this url.", style: "display:inline;margin-right:20px"
          @a "Click here.", href: params.url, style: "width:10%"
        @subview "url", new TextEditorView(mini:true), style: "width:90%"
      @div =>
        @h2 "2. Copying the code after authenticating in google."
      @div =>
        @h2 "3. Paste code."
        @subview "input", new TextEditorView(mini:true, placeholderText: "Paste here.")
      @div =>
        @button "Enter", outlet: "enter", class: "btn", style: "float:right"

  initialize: (params, self) ->
    @self = self
    @url.setText(params.url)
    @handleEvents(params)

  handleEvents: (params) ->
    @enter.click =>
      @self.inputCode(params.oauth2Client, @input.getText(), params.callback)
      @self.panelHide()
    @input.on "keyup", (e) =>
      if e.keyCode is 27 # esc
        @self.panelHide()
      else if e.keyCode is 13 # enter
        @self.inputCode(params.oauth2Client, @input.getText(), params.callback)
        @self.panelHide()
