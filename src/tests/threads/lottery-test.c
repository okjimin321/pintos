#include <stdio.h>
#include "tests/threads/tests.h"
#include "threads/init.h"
#include "threads/thread.h"
#include "devices/timer.h"

static volatile unsigned long long counter[3];
static volatile bool thread_exit_flag = false;

static void counter_thread(void *aux){
    int id = *(int *)aux;
    for(;;){
        counter[id]++;
        if(thread_exit_flag)
          thread_exit();
    }

}

void test_lottery(void){
    int ids[3] = {0, 1, 2}; // 0: high, 1: medium, 2: low

    msg("Starting lottery scheduler test...");

    thread_create("high",   30, counter_thread, &ids[0]);
    thread_create("medium", 20, counter_thread, &ids[1]);
    thread_create("low",    10, counter_thread, &ids[2]);

    int sleep_duration = 500;
    msg("sleep_duration = %d",sleep_duration);
    timer_sleep(sleep_duration);
    thread_exit_flag = true;

    msg("High priority thread ran %llu times.", counter[0]);
    msg("Medium priority thread ran %llu times.", counter[1]);
    msg("Low priority thread ran %llu times.", counter[2]);
    
    printf("%llu, %llu, %llu \n", counter[0], counter[1], counter[2]);

    unsigned long long sum = counter[0] + counter[1] + counter[2];
    if(counter[2] > 0){
        unsigned long long h = (counter[0]*1000) / counter[2];
        unsigned long long m = (counter[1]*1000) / counter[2];
        msg("%llu.%03llu : %llu.%03llu : 1.000", h/1000,h%1000,m/1000,m%1000);
    }
}