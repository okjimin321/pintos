# INHA University Pintos Projects

This repository contains the implementation of key Pintos projects as part of the INHA University Operating Systems course.

## Project 1: Sleep and Awake Implementation

- **Implement the `timer_sleep()` and `timer_awake()` functions** to put threads to sleep for a specified number of timer ticks, and then move them back to the ready list after the sleep duration expires.  
- **Manage thread states** to efficiently block and wake threads.  
- **Modify the timer interrupt handler** to wake sleeping threads when their sleep duration expires.  
- **Ensure proper synchronization and timing behavior.**

## Project 2: Lottery Scheduling Implementation

- **Replace the default priority scheduler** with a lottery scheduling algorithm.  
- **Modify scheduling logic** to randomly select threads based on their ticket counts.  
- **Implement fairness measurement (lottery-test)** by tracking how often each thread runs.
