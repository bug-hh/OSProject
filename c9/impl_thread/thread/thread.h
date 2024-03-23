#ifndef __THREAD_THREAD_H
#define __THREAD_THREAD_H

#include "stdint.h"

typedef void thread_func(void*);

enum task_status {
  TASK_RUNNING,
  TASK_READY,
  TASK_BLOCKED,
  TASK_WAITING,
  TASK_HANGING,
  TASK_DIED
};

// 中断栈 intr_stack
struct intr_stack {
  uint32_t vec_no;   // kernel.S 宏VECTOR中 push %1 压入的中断号
  uint32_t edi;
  uint32_t esi;
  uint32_t ebp;
  uint32_t esp_dummy;
  
  uint32_t ebx;
  uint32_t edx;
  uint32_t ecx;
  uint32_t eax;
  uint32_t gs;
  uint32_t fs;
  uint32_t es;
  uint32_t ds;
  
  uint32_t err_code;
  void (*eip) (void);
  uint32_t cs;
  uint32_t eflags;
  void* esp;
  uint32_t ss;
};

// 线程栈 
struct thread_stack {
  uint32_t ebp;
  uint32_t ebx;
  uint32_t edi;
  uint32_t esi;
  
  // 线程第一次执行时，eip 指向待调用的函数 kernel_thread
  // 其他时候， eip 是指向 switch_to 的返回地址
  void (*eip) (thread_func* func, void* func_arg);
  
  // 参数 unused_ret 只为占位置充数为返回地址
  void (*unused_retaddr);
  // 由 kernel_thread 所调用的函数名
  thread_func* function;
  // 由 kernel_thread 所调用的函数所需的参数
  void* func_arg;
};

// 进程或线程的 pcb
struct task_struct {
  // 各内核线程都用自己的内核栈
  uint32_t* self_kstack;
  enum task_status status;
  // 线程优先级
  uint8_t priority;
  char name[16];
  // 栈的边界标记，用于检测栈的溢出
  uint32_t stack_magic;
};

struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg);

#endif