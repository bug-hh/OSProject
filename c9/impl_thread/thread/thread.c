#include "thread.h"
#include "stdint.h"
#include "string.h"
#include "global.h"
#include "memory.h"

#define PG_SIZE 4096

// 由 kernel_thread 去执行 function(func_arg)
static void kernel_thread(thread_func* function, void* func_arg) {
  function(func_arg);
}

// 初始化线程栈 thread_stack
// 将待执行的函数和参数放到 thread_stack 中相应的位置
void thread_create(struct task_struct* pthread, thread_func function, void* func_arg) {
  // 预留中断栈使用的空间
  pthread->self_kstack -= sizeof(struct intr_stack);
  
  // 再留出线程栈空间
  pthread->self_kstack -= sizeof(struct thread_stack);
  struct thread_stack* kthread_stack = (struct thread_stack*)pthread->self_kstack;
  kthread_stack->eip = kernel_thread;
  kthread_stack->function = function;
  kthread_stack->func_arg = func_arg;
  kthread_stack->ebp = kthread_stack->ebx = \
  kthread_stack->esi = kthread_stack->edi = 0;
}

// 初始化线程基本信息
void init_thread(struct task_struct* pthread, char* name, int prio) {
  memset(pthread, 0, sizeof(*pthread));
  strcpy(pthread->name, name);
  pthread->status = TASK_RUNNING;
  pthread->priority = prio;
  pthread->self_kstack = (uint32_t*)((uint32_t)pthread + PG_SIZE);
  pthread->stack_magic = 0x19870916;
}

struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg) {
  struct task_struct* thread = get_kernel_pages(1);
  init_thread(thread, name, prio);
  /*
  movl l 表示操作数是 32 位的
  volatile 告诉编译器，不要修改我的汇编代码
  */
  asm volatile ("movl %0, %%esp; pop %%ebp; pop %%ebx; pop %%edi; pop %%esi; \
  ret": : "g" (thread->self_kstack) : "memory");
  return thread;
}