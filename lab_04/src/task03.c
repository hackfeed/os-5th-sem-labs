#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>

#define N 2

int pid;
int child_pids[N];
const char *const COMMANDS[N] = {"ls", "whoami"};

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
            printf("Child process : PID=%d, GROUP=%d, PPID=%d\n\n", getpid(), getpgrp(), getppid());

            switch (execlp(COMMANDS[i], COMMANDS[i], 0))
            {
            case -1:
                perror("Can't exec\n");

                return 1;
            case 0:
                return 0;
            }
        default:
            child_pids[i] = pid;
        }
    }

    for (size_t i = 0; i < N; ++i)
    {
        int status, stat_val;
        pid_t childpid = wait(&status);

        printf("\nChild process has finished: PID = %d, status = %d\n", childpid, status);

        if (WIFEXITED(stat_val))
        {
            printf("Child process exited with code %d\n", WEXITSTATUS(stat_val));
        }
        else
        {
            printf("Child process terminated abnormally\n");
        }
    }

    printf("Parent process have children with IDs: %d, %d\n", child_pids[0], child_pids[1]);
    printf("Parent process is dead now\n");

    return 0;
}