#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/types.h>

#define N 2
#define BUFLEN 100
#define INTERVAL 5

int pid;
int child_pids[N];
const char *PIPEMSG[N] = {"message1", "message2"};
int state = 0;

void reverse(char *x, int begin, int end)
{
    char c;

    if (begin >= end)
        return;

    c = *(x + begin);
    *(x + begin) = *(x + end);
    *(x + end) = c;

    reverse(x, ++begin, --end);
}

void reverse_buf(int sig)
{
    state = 1;
}

int main()
{
    int fd[2];
    char buffer[BUFLEN] = {0};

    printf("Parent process: PID=%d, GROUP=%d\n", getpid(), getpgrp());

    if (pipe(fd) == -1)
    {
        perror("Can't pipe\n");

        return 1;
    }

    signal(SIGINT, reverse_buf);

    for (size_t i = 0; i < N; ++i)
    {
        switch (pid = fork())
        {
        case -1:
            perror("Can't fork\n");

            exit(1);
        case 0:
            close(fd[0]);
            write(fd[1], PIPEMSG[i], strlen(PIPEMSG[i]));
            printf("Message has been sent to parent\n");

            exit(0);
        default:
            child_pids[i] = pid;
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

    close(fd[1]);
    read(fd[0], buffer, BUFLEN);
    sleep(INTERVAL);

    if (state)
    {
        reverse(buffer, 0, strlen(buffer) - 1);
    }

    printf("Received message: %s\n", buffer);

    printf("Parent process have children with IDs: %d, %d\n", child_pids[0], child_pids[1]);
    printf("Parent process is dead now\n");

    return 0;
}