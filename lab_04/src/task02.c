#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>

#define N 2
#define INTERVAL 5

int main()
{
    printf("Parent process: PID=%d, GROUP=%d\n", getpid(), getpgrp());

    for (size_t i = 0; i < N; ++i)
    {
        switch (fork())
        {
        case -1:
            perror("Can't fork\n");

            return 1;
        case 0:
            printf("Child process : PID=%d, GROUP=%d, PPID=%d\n", getpid(), getpgrp(), getppid());
            sleep(INTERVAL);

            return 0;
        }
    }

    for (size_t i = 0; i < N; ++i)
    {
        int status, stat_val;
        pid_t childpid = wait(&status);

        printf("Child process has finished: PID = %d, status = %d\n", childpid, status);

        if (WIFEXITED(stat_val))
        {
            printf("Child process exited with code %d\n", WEXITSTATUS(stat_val));
        }
        else
        {
            printf("Child process terminated abnormally\n");
        }
    }

    printf("Parent process is dead now\n");

    return 0;
}