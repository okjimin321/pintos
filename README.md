# Pintos Projects

## Project 1: Alarm Clock & Scheduling
- **Alarm Clock**  
  - Implements `timer_sleep()` and `timer_awake()`  
  - Manages thread blocking and waking based on timer ticks  
- **Proportional Scheduling**  
  - Implements Lottery Scheduling  
  - Implements Stride Scheduling  
  - Implements Completely Fair Scheduler (CFS)  

## Project 2: System Calls (Process Management)
- `halt()` → Shuts down the system  
- `exit(int status)` → Terminates the current process with a status  
- `exec(const char* cmd_line)` → Starts a new process  
- `wait(tid_t child_tid)` → Waits for a child process to terminate  

## Project 3: System Calls (File Management)
- `create(const char* file, unsigned initial_size)` → Creates a new file  
- `remove(const char* file)` → Deletes a file  
- `open(const char* file)` → Opens a file and returns a file descriptor  
- `filesize(int fd)` → Returns the size of the file  
- `read(int fd, void* buffer, unsigned size)` → Reads data from a file or stdin  
- `write(int fd, const void* buffer, unsigned size)` → Writes data to a file or stdout  
- `seek(int fd, unsigned position)` → Changes the file pointer position  
- `tell(int fd)` → Returns the current position of the file pointer  
- `close(int fd)` → Closes a file descriptor  

