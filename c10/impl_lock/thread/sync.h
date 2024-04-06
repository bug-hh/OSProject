#ifndef __THREAD_SYNC_H
#define __THREAD_SYNC_H
#include "list.h"
#include "stdint.h"
#include "thread.h"


struct semaphore {
  uint8_t value;
  struct list waiters;
};

struct lock {
  // 锁的持有者
  struct task_struct* holder;
  // 用二元信号量实现锁
  struct semaphore sema;
  // 锁的持有者重复申请锁的次数
  uint32_t holder_repeat_nr;
};

void sema_init(struct semaphore* psema, uint8_t value);
void sema_down(struct semaphore* psema);
void sema_up(struct semaphore* psema);

void lock_init(struct lock* plock);
void lock_acquire(struct lock* plock);
void lock_release(struct lock* plock);

#endif;