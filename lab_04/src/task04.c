#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <sys/types.h>

#define N 2
#define BUFLEN 100

const char *PIPEMSG[N] = {"message1", "message2"};

int main()
{
    int fd[2];
    char buffer[BUFLEN] = {0};

    if (pipe(fd) == -1)
    {
        perror("Can't pipe\n");

        return 1;
    }

    for (size_t i = 0; i < N; ++i)
    {
        switch (fork())
        {
        case -1:
            perror("Can't fork\n");

            exit(1);
        case 0:
            close(fd[0]);
            write(fd[1], PIPEMSG[i], strlen(PIPEMSG[i]));
            printf("Message has been sent to parent\n");

            exit(0);
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
    printf("Received message: %s\n", buffer);

    printf("Parent process is dead now\n");

    return 0;
}