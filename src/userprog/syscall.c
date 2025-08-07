#include "userprog/syscall.h"
#include <stdio.h>
#include <syscall-nr.h>
#include "threads/interrupt.h"
#include "threads/thread.h"
#include "filesys/inode.h"
#include "devices/shutdown.h"
#include "threads/vaddr.h"



static void syscall_handler (struct intr_frame *);

void check_address(void* vaddr);

tid_t exec(const char* cmd_line);
int write(int fd, const void* buffer, unsigned size);
void exit(int status);
int open(const char* file);
int filesize(int fd);
void halt(void);
bool create(const char* file, unsigned initial_size);
int read(int fd, void* buffer, unsigned size);
void seek(int fd, unsigned position);
bool create(const char* file, unsigned initial_size);
bool remove(const char* file);
void close(int fd);
unsigned tell(int fd);
int wait(tid_t child_tid);

struct lock file_lock;

void check_address(void* vaddr){
  if(vaddr == NULL)
    exit(-1);
  if(is_kernel_vaddr(vaddr))
    exit(-1);
  if(pagedir_get_page(thread_current()->pagedir, vaddr) == NULL)
    exit(-1);
}


void
syscall_init (void) 
{
  intr_register_int (0x30, 3, INTR_ON, syscall_handler, "syscall");
  lock_init(&file_lock);
}

static void
syscall_handler (struct intr_frame *f UNUSED) 
{
  check_address(f->esp);

  int syscall_num = (int)*(uint32_t*)f->esp;
  switch(syscall_num){
    case SYS_HALT:
      shutdown_power_off();
      break;
    case SYS_EXIT:{
      check_address(f->esp + 4);
      int status = (int)*(uint32_t*)(f->esp + 4);
      exit(status);
      break; 
    }
    case SYS_EXEC:{
      check_address(f->esp + 4);
      const char* cmd_line = (const char*)*(uint32_t*)(f->esp + 4);
      f->eax = exec(cmd_line);
      break;
    }
    case SYS_WAIT:{
      check_address(f->esp + 4);
      int child_tid = (int)*(uint32_t*)(f->esp + 4);
      f->eax = wait(child_tid);  
      break;
    }
    case SYS_CREATE:{
      check_address(f->esp + 4);
      check_address(f->esp + 8);
      const char* file = (char*)*(uint32_t*)(f->esp + 4);
      unsigned int initial_size = (unsigned)*(uint32_t*)(f->esp + 8);
      f->eax = create(file, initial_size);
      break;
    }
    case SYS_REMOVE:{
      check_address(f->esp + 4);
      const char* file = (const char*)*(uint32_t*)(f->esp + 4);
      f->eax = remove(file);
      break;
    }
    case SYS_OPEN:{
      check_address(f->esp + 4);
      const char* file = (char*)*(uint32_t*)(f->esp + 4);
      f->eax = open(file);
      break;
    }
    case SYS_FILESIZE:{
      check_address(f->esp + 4);
      int fd = (int)*(uint32_t*)(f->esp + 4);
      f->eax = filesize(fd);
      break;
    }
    case SYS_READ:{// need to fix
    check_address(f->esp + 4);
    check_address(f->esp + 8);
    check_address(f->esp + 12);
      int fd = (int)*(uint32_t*)(f->esp + 4);
      void * buf = (void*)*(uint32_t*)(f->esp + 8);
      unsigned int size = (int)*(uint32_t*)(f->esp + 12);
      f->eax = read(fd, buf, size);
      break;
    }
    case SYS_WRITE:{
      check_address(f->esp + 4);
      check_address(f->esp + 8);
      check_address(f->esp + 12);
      int fd = (int)*(uint32_t*)(f->esp + 4);
      void * buf = (void*)*(uint32_t*)(f->esp + 8);
      unsigned int size = (int)*(uint32_t*)(f->esp + 12);
      f->eax = write(fd, buf, size);
      break;
    }
    case SYS_SEEK:{
      check_address(f->esp + 4);
      check_address(f->esp + 8);
      int fd = (int)*(uint32_t*)(f->esp + 4);
      unsigned position = (unsigned)*(uint32_t*)(f->esp + 8);
      seek(fd, position);
      break;
    }
    case SYS_TELL:{
      check_address(f->esp + 4);
      int fd = (int)*(uint32_t*)(f->esp + 4);
      f->eax = tell(fd);
      break;
    }
    case SYS_CLOSE:{
      check_address(f->esp + 4);
      int fd = (int)*(uint32_t*)(f->esp + 4);
      close(fd);
      break;
    }
    default:
      exit(-1);
  }
}

int wait(tid_t child_tid){
  return process_wait(child_tid);
}

tid_t exec(const char* cmd_line){
  check_address(cmd_line);
  tid_t child_tid = process_execute(cmd_line);
  return child_tid;
}

bool remove(const char* file){
  check_address(file);
  return filesys_remove(file);
}

bool create(const char* file, unsigned initial_size){
  check_address(file);
  return filesys_create(file, initial_size);
}

void seek(int fd, unsigned position){
  struct file* f = process_get_file(fd);
  file_seek(f, position);
}

unsigned tell(int fd){
  struct file* f = process_get_file(fd);
  return file_tell(f);
}

void exit(int status){
  printf("%s: exit(%d)\n", thread_current()->name, status);
  thread_current()->exit_status = status;
  thread_exit();
}

int open(const char* file){
  check_address(file);
  struct file* f = filesys_open(file);
  if(f == NULL){
    return -1;  
  }
  if(*thread_current()->name == *file){// 실행파일 write하려하면 deny해야 함
    file_deny_write(f);
  }
  int fd = process_add_file(f);
  return fd;
}

void close(int fd){
  if(fd <= 1){
    exit(-1);
  }
  else if(fd < FD_SIZE){
    struct file* f = process_get_file(fd);
    if(f == NULL){
      exit(-1);
    }
    thread_current()->fd_table[fd] = NULL;
    file_close(f);
  }
  else{
    exit(-1);
  }
}

int filesize(int fd){
  struct file* f = process_get_file(fd);
  if(f == NULL)
    return -1;
  return file_length(f);
}

int read(int fd, void* buffer, unsigned size){
  check_address(buffer);
  if(fd == 0){
    int read_byte = 0;
    char c;
    while(read_byte < size){
      c = input_getc();
      *(char*)(buffer + read_byte) = c;
      read_byte++;
    }
    return read_byte;
  }
  else if(fd >= 2 && fd < FD_SIZE){
    struct file* f = process_get_file(fd);
    if(f == NULL){
      return -1;
    }
    int read_byte = file_read(f, buffer, size);
    return read_byte;
  }
  else{
    return -1;
  }
}

int write(int fd, const void* buffer, unsigned size){
  /*
  fd == 0: stdin
  fd == 1: stdout
  fd >= 2: file descriptor 
  buffer: has data to print
  */
  check_address(buffer);
  if(fd == 1){
    putbuf(buffer, size);// Prints accroding to size
    return size;
  }
  else if(fd >= 2 && fd < FD_SIZE){
    lock_acquire(&file_lock);
    struct file* f = process_get_file(fd);
    if(f == NULL){
      lock_release(&file_lock);
      return -1;
    }
    int write_byte = file_write(f, buffer, size);
    lock_release(&file_lock);
    return write_byte;
  }
  else{
    return -1;
  }
}

