#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"
#include "thread.h"

void k_thread_a(void*);

int main() {
  put_str("I am kernel\n");
  init_all();
  
  thread_start("k_thread_a", 31, k_thread_a, "argA ");
  while (1);
  return 0;
}

void k_thread_a(void* arg) {
  char* para = arg;
  int i = 0;
  while(i++<10) {
    put_str(para);
  }
}