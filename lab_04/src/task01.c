#include <stdio.h>
#include <unistd.h>

#define N 2
#define INTERVAL 30

int pid;
int child_pids[N];

int main()
{
    printf("Parent process: PID=%d, GROUP=%d\n", getpid(), getpgrp());

    for (size_t i = 0; i < N; ++i)
    {
        switch (pid = fork())
        {
        case -1:
            perror("Can't fork\n");

            return 1;
        case 0:
            printf("Child process : PID=%d, GROUP=%d, PPID=%d\n", getpid(), getpgrp(), getppid());
            sleep(INTERVAL);

            return 0;
        default:
            child_pids[i] = pid;
        }
    }

    printf("Parent process have children with IDs: %d, %d\n", child_pids[0], child_pids[1]);
    printf("Parent process is dead now\n");

    return 0;
}