parseOrigin = (url) ->
  a = window.document.createElement 'a'
  a.href = url
  a.protocol + '//' + a.host

parsePath = (url) ->
  a = window.document.createElement 'a'
  a.href = url
  a.pathname + a.search + a.hash

createIframe = (src) ->
  iframe = window.document.createElement 'iframe'
  iframe.src = src
  iframe.width = 0
  iframe.height = 0
  iframe.style.display = 'none'
  iframe

addMessageListener = (origin, pattern, callback) ->
  window.addEventListener 'message', (e) ->
    return if e.origin != origin
    matchData = e.data.match(pattern)
    callback.apply(this, [e.source, e.data].concat(matchData)) if matchData

hosts = {}
nextMsgIdentifier = 1

exports.host = (path, insertFrame) ->
  origin = parseOrigin(path)
  insertFrame ?= (e) -> window.document.body.appendChild(e)

  return if hosts[origin]?

  frame = createIframe(path)
  insertFrame(frame)

  sendRequests = null

  toSend = {}
  toReceive = {}

  hosts[origin] = (options, callback) ->
    toSend[nextMsgIdentifier] = { options: options, callback: callback }
    nextMsgIdentifier++
    sendRequests() if sendRequests

  addMessageListener origin, /^viaduct-callback-([0-9]+) (.*)$/, (source, data, match, id, args) ->
    parsedArgs = JSON.parse(args)
    parsedArgs[1].getAllResponseHeaders = () -> parsedArgs[1]._viaductHeaders
    toReceive[id](parsedArgs...)

  addMessageListener origin, /^viaduct-loaded$/, (source) ->
    sendRequests = () ->
      Object.keys(toSend).forEach (key) ->
        source.postMessage(JSON.stringify({ id: key, options: toSend[key].options }), origin)
        toReceive[key] = toSend[key].callback
      toSend = {}

    sendRequests()

exports.request = (options, callback) ->
  throw new Error('Bad callback given: ' + callback) if typeof callback != 'function'
  throw new Error('No options given') if !options?

  options = { uri: options } if typeof options == 'string'

  if options.url
    options.uri = options.url
    delete options.url

  throw new Error("options.uri is a required argument") if !options.uri?
  throw new Error("options.uri must be a string") if typeof options.uri != "string"

  origin = parseOrigin(options.uri)
  path = parsePath(options.uri)

  options.uri = path
  sendMethod = hosts[origin]

  throw new Error('Host not added') if !sendMethod?

  sendMethod(options, callback)
