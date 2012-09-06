module Wtmp
  EMPTY = 0
  RUNLEVEL = 1
  BOOT_TIME = 2
  NEW_TIME = 3
  OLD_TIME = 4
  INIT_PROCESS = 5
  LOGIN_PROCESS = 6
  USER_PROCESS = 7
  DEAD_PROCESS = 8
  ACCOUTNING = 9
  
  UT_LINESIZE = 32
  UT_NAMESIZE = 32
  UT_HOSTSIZE = 256

  #To do: handle case where system only supports 64-bit operation (some wtmp entries will change to 64-bit).

  def entries()
    wtmp = File.read("/var/log/wtmp")
    until wtmp.empty?
      data = wtmp.unpack("slA#{UT_LINESIZE}a4A${UT_NAMESIZE}A{UT_HOSTSIZE}s2l3")
      puts data
      data = data[382 .. -1]
    end
  end
end