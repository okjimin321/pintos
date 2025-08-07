#ifndef USERPROG_PROCESS_H
#define USERPROG_PROCESS_H

#include "threads/thread.h"

tid_t process_execute (const char *file_name);
int process_wait (tid_t);
void process_exit (void);
void process_activate (void);
int process_add_file(struct file* file);
struct file* process_get_file(int fd);
static void push_args(void**,char*file_name);

#endif /* userprog/process.h */
