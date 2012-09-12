#include <stdio.h>
#include <string.h>
#include <utmp.h>

#include "ruby.h"

VALUE StatMonitorModule;
VALUE UtmpModule;

static VALUE module_function_users(VALUE self, VALUE filename) {
  StringValue(filename);
  char* cFilename = StringValueCStr(filename);
  VALUE users = rb_ary_new();
  size_t numEntries;
  FILE *file;
  size_t fileSize;
  size_t i;
  struct utmp utmp_buf;

  //Open file.
  file = fopen(cFilename, "rb");
  if(!file) {
    //Note: unable to free buffer. Can this be fixed?
    char buf[512] = "Unable to open ";
    //Copy into the message buffer.
    strncpy(buf + strlen(buf), cFilename, 512 - 1 - strlen(buf));
    //Make sure the buffer ends with a null character.
    buf[511] = '\0';
    //Free the filename string.
    free(cFilename);
    rb_raise(rb_eIOError, buf);
  }

  //Get file size.
  fseek(file, 0L, SEEK_END);
  fileSize = ftell(file);
  rewind(file);
  
  if((fileSize % sizeof(struct utmp)) != 0) {
    rb_raise(rb_eException, "/var/run/utmp appears to be the wrong size.");
  }
  
  //Read each entry.
  while(fread(&utmp_buf, sizeof(struct utmp), 1, file) == 1) {
    if( utmp_buf.ut_type == USER_PROCESS) {
      rb_ary_push(users, rb_str_new2(utmp_buf.ut_user));
    }
  }
  
  fclose(file);
  free(cFilename);

  return users;
}

void Init_utmp() {
  StatMonitorModule = rb_define_module("StatMonitor");
  UtmpModule = rb_define_module_under(StatMonitorModule, "Utmp");
  rb_define_module_function(UtmpModule, "users", module_function_users, 1);
}
