#!/usr/bin/python
# -*- coding: utf-8 -*-

import websocket
import sys
import logging as log

websocketURL = sys.argv[1]
websocketInputJSONData = sys.argv[2]
websocketOutputFile = sys.argv[3]

log.basicConfig( level = log.INFO )

log.debug( 'URL = "' + websocketURL + '"' )
log.debug( 'JSON DATA = "' + websocketInputJSONData + '"' )
log.debug( 'Output File = "' + websocketOutputFile + '"' )

ws = websocket.create_connection( websocketURL )
log.debug( 'Sending JSON DATA : ' + websocketInputJSONData )
ws.send( websocketInputJSONData )
log.debug( 'Receiving binary DATA ...' )
data =  ws.recv()
ws.close()
log.debug( 'Writing data to file' + websocketOutputFile )
f = open( websocketOutputFile ,'wb')
f.write( data )
f.close()
