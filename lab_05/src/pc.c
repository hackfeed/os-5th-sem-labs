#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <wait.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <sys/types.h>

#define N 24
#define MAX_SEMS 3
#define ITERS 8

#define P_COUNT 3
#define C_COUNT 3

#define BIN_SEM 0
#define BUF_FULL 1
#define BUF_EMPTY 2

#define MAX_RAND_P 2
#define MAX_RAND_C 5

typedef char data_t[N];
typedef struct
{
    size_t r_pos;
    size_t w_pos;
    data_t data;
} cbuf_t;

struct sembuf P_LOCK[2] = {{BUF_EMPTY, -1, 0}, {BIN_SEM, -1, 0}};
struct sembuf P_RELEASE[2] = {{BUF_FULL, 1, 0}, {BIN_SEM, 1, 0}};

struct sembuf C_LOCK[2] = {{BUF_FULL, -1, 0}, {BIN_SEM, -1, 0}};
struct sembuf C_RELEASE[2] = {{BUF_EMPTY, 1, 0}, {BIN_SEM, 1, 0}};

int init_buf(cbuf_t *const buf)
{
    if (!buf)
    {
        return -1;
    }
    memset(buf, 0, sizeof(cbuf_t));

    return 0;
}

int write_buf(cbuf_t *const buf, const char c)
{
    if (!buf)
    {
        return -1;
    }
    buf->data[buf->w_pos++] = c;
    buf->w_pos %= N;

    return 0;
}

int read_buf(cbuf_t *const buf, char *const dst)
{
    if (!buf)
    {
        return -1;
    }
    *dst = buf->data[buf->r_pos++];
    buf->r_pos %= N;

    return 0;
}

int p_run(cbuf_t *const buf, const int s_id, const int p_id)
{
    if (!buf)
    {
        return -1;
    }

    srand(time(NULL) + p_id);

    int stime;
    char ch;

    for (size_t i = 0; i < ITERS; ++i)
    {
        stime = rand() % MAX_RAND_P + 1;
        sleep(stime);

        if (semop(s_id, P_LOCK, 2) == -1)
        {
            perror("Producer lock error.");

            exit(EXIT_FAILURE);
        }

        ch = 'a' + (char)(buf->w_pos % 26);

        if (write_buf(buf, ch) == -1)
        {
            perror("Buffer write error.");

            return EXIT_FAILURE;
        }
        printf("!Producer #%d wrote: %c // Idle time: %ds\n", p_id, ch, stime);

        if (semop(s_id, P_RELEASE, 2) == -1)
        {
            perror("Producer release error.");

            exit(EXIT_FAILURE);
        }
    }

    return EXIT_SUCCESS;
}

int c_run(cbuf_t *const buf, const int s_id, const int c_id)
{
    if (!buf)
    {
        return -1;
    }

    srand(time(NULL) + c_id + P_COUNT);

    int stime;
    char ch;

    for (size_t i = 0; i < ITERS; ++i)
    {
        stime = rand() % MAX_RAND_C + 1;
        sleep(stime);

        if (semop(s_id, C_LOCK, 2) == -1)
        {
            perror("Consumer lock error.");

            exit(EXIT_FAILURE);
        }

        if (read_buf(buf, &ch) == -1)
        {
            perror("Buffer read error.");

            return EXIT_FAILURE;
        }
        printf("?Consumer #%d read:  %c // Idle time: %ds\n", c_id, ch, stime);

        if (semop(s_id, C_RELEASE, 2) == -1)
        {
            perror("Consumer release error.");

            exit(EXIT_FAILURE);
        }
    }

    return EXIT_SUCCESS;
}

int main()
{
    setbuf(stdout, NULL);

    int fd = shmget(IPC_PRIVATE, sizeof(cbuf_t), IPC_CREAT | S_IRWXU | S_IRWXG | S_IRWXO);
    if (fd == -1)
    {
        perror("shmget failed.");

        return EXIT_FAILURE;
    }

    cbuf_t *buf = shmat(fd, 0, 0);
    if (buf == (void *)-1)
    {
        perror("shmat failed.");

        return EXIT_FAILURE;
    }

    if (init_buf(buf) == -1)
    {
        perror("Buffer initialization failed.");

        return EXIT_FAILURE;
    }

    int s_id = semget(IPC_PRIVATE, MAX_SEMS, IPC_CREAT | S_IRWXU | S_IRWXG | S_IRWXO);
    if (s_id == -1)
    {
        perror("semget failed.");

        return EXIT_FAILURE;
    }

    semctl(s_id, BIN_SEM, SETVAL, 1);
    semctl(s_id, BUF_EMPTY, SETVAL, N);
    semctl(s_id, BUF_FULL, SETVAL, 0);

    int chpid;
    for (size_t i = 0; i < P_COUNT; ++i)
    {
        switch ((chpid = fork()))
        {
        case -1:
            perror("Producer fork failed.");

            exit(EXIT_FAILURE);
            break;
        case 0:
            p_run(buf, s_id, i);

            return EXIT_SUCCESS;
        }
    }

    for (size_t i = 0; i < C_COUNT; ++i)
    {
        switch ((chpid = fork()))
        {
        case -1:
            perror("Consumer fork failed.");

            exit(EXIT_FAILURE);
            break;
        case 0:
            c_run(buf, s_id, i);
            return EXIT_SUCCESS;
        }
    }

    for (size_t i = 0; i < C_COUNT + P_COUNT; ++i)
    {
        int status;
        if (wait(&status) == -1)
        {
            perror("Child error.");

            exit(EXIT_FAILURE);
        }
        if (!WIFEXITED(status))
        {
            printf("Child process terminated abnormally\n");
        }
    }

    if (shmdt((void *)buf) == -1 ||
        shmctl(fd, IPC_RMID, NULL) == -1 ||
        semctl(s_id, IPC_RMID, 0) == -1)
    {
        perror("Exit error.");

        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
