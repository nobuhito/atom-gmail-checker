{View} = require 'atom-space-pen-views'
module.exports =
class AtomGmailCheckerPreviewView extends View
  @content: (params)->
    @div class: "inline-block atom-gmail-check-preview", =>
      @a href: "https://mail.google.com/mail/u/#{params.userId}/#search/is%3Aunread", outlet: "link", =>
        @span "", outlet: "preview"

  setSnippet: (snippet) ->
    @preview.text snippet
