#include "ruby.h"

VALUE UtmpModule;

static VALUE module_function_entries(VALUE filename) {
  return Qnil;
}

void Init_stat_monitor() {
  UtmpModule = rb_define_module("Utmp");
  rb_define_module_function(UtmpModule, "entries", module_function_entries, 1);
}
