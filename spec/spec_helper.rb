require 'statmonitor'

def testMsg(msg, config)
  socket = TCPSocket.open('127.0.0.1', config.port)
  socket.puts(msg)

  gotMessage = IO.select([socket], nil, nil, 3)

  return JSON.parse(socket.gets) if gotMessage

  nil
end
