#include "sync.h"
#include "list.h"
#include "global.h"
#include "debug.h"
#include "interrupt.h"

void sema_init(struct semaphore* psema, uint8_t value) {
  psema->value = value;
  list_init(&psema->waiters);
}

void lock_init(struct lock* plock) {
  plock->holder = NULL;
  plock->holder_repeat_nr = 0;
  sema_init(&plock->sema, 1);
}

void sema_down(struct semaphore* psema) {
  // 关中断，保证原子操作，保证在执行指令时，不被打断
  enum intr_status old_status = intr_disable();
  // 如果是 0，表示锁已经被其他线程持有
  while (psema->value == 0) {
    // 确保当前线程不在信号量的等待队列里
    ASSERT(!elem_find(&psema->waiters, &running_thread()->general_tag));
    if (elem_find(&psema->waiters, &running_thread()->general_tag)) {
      PANIC("sema_down: thread blocked has been in waiter_list\n");
    }
    // 把当前线程加入到等待队列中
    list_append(&psema->waiters, &running_thread()->general_tag);
    // 当前线程主动阻塞自己
    thread_block(TASK_BLOCKED);
  }
  psema->value--;
  ASSERT(psema->value == 0);
  intr_set_status(old_status);
}

void sema_up(struct semaphore* psema) {
  // 关中断，保证原子操作，保证在执行指令时，不被打断
  enum intr_status old_status = intr_disable();
  ASSERT(psema->value == 0);
  if (!list_empty(&psema->waiters)) {
    struct task_struct* thread_blocked = elem2entry(struct task_struct, general_tag, list_pop(&psema->waiters));
    thread_unblock(thread_blocked);
  }
  psema->value++;
  ASSERT(psema->value == 1);
  intr_set_status(old_status);
}

void lock_acquire(struct lock* plock) {
  if (plock->holder != running_thread()) {
    sema_down(&plock->sema);
    plock->holder = running_thread();
    ASSERT(plock->holder_repeat_nr == 0);
    plock->holder_repeat_nr = 1;
  } else {
    plock->holder_repeat_nr++;
  }
}

void lock_release(struct lock* plock) {
  ASSERT(plock->holder == running_thread());
  if (plock->holder_repeat_nr > 1) {
    plock->holder_repeat_nr--;
    return;
  }
  ASSERT(plock->holder_repeat_nr == 1);
  plock->holder = NULL;
  plock->holder_repeat_nr = 0;
  sema_up(&plock->sema);
}