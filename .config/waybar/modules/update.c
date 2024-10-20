#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/file.h>

#define LOG_FILE "/var/tmp/update.log"
#define LOCK_FILE "/var/tmp/update.lock"
#define MIRROR_LOCK_FILE "/var/tmp/mirror.lock"
#define BUFFER_SIZE 128
#define CMD_LEN 128

const char *managers[] = {"yay", "paru", "pacman"};

static int create_lock_file(const char *lock_file)
{
  int lock_fd = open(lock_file, O_CREAT | O_RDWR, 0600);
  if (lock_fd == -1 || flock(lock_fd, LOCK_EX | LOCK_NB) == -1)
  {
    if (lock_fd != -1) close(lock_fd);
    return -1;
  }
  return lock_fd;
}

static int run_command(const char *cmd, FILE *log_fp)
{
  int pipe_fd[2];
  if (pipe(pipe_fd) == -1) return -1;

  pid_t pid = fork();
  if (pid == -1) return -1;

  if (pid == 0)
  {
    close(pipe_fd[0]);
    dup2(pipe_fd[1], STDOUT_FILENO);
    dup2(pipe_fd[1], STDERR_FILENO);
    close(pipe_fd[1]);
    execlp("/bin/bash", "bash", "-c", cmd, NULL);
    _exit(EXIT_FAILURE);
  }

  close(pipe_fd[1]);
  char buffer[BUFFER_SIZE];
  ssize_t bytes;
  while ((bytes = read(pipe_fd[0], buffer, sizeof(buffer) - 1)) > 0)
  {
    buffer[bytes] = '\0';
    fputs(buffer, log_fp);
  }
  close(pipe_fd[0]);

  int status;
  waitpid(pid, &status, 0);
  return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

int main()
{
  if (geteuid() != 0)
  {
    fprintf(stderr, "This script requires root privileges.\n");
    return EXIT_FAILURE;
  }

  int lock_fd = create_lock_file(LOCK_FILE);
  if (lock_fd == -1)
  {
    fprintf(stderr, "Another instance of the script is running.\n");
    return EXIT_FAILURE;
  }

  struct stat st;
  if (stat(MIRROR_LOCK_FILE, &st) == 0)
  {
    fprintf(stderr, "Mirror update in progress. Cannot proceed with updates.\n");
    close(lock_fd);
    return EXIT_FAILURE;
  }

  FILE *log_fp = fopen(LOG_FILE, "w");
  if (!log_fp)
  {
    perror("Failed to open log file");
    close(lock_fd);
    return EXIT_FAILURE;
  }

  bool update_success = false;
  for (size_t i = 0; i < sizeof(managers) / sizeof(managers[0]); i++)
  {
    char command[CMD_LEN];
    snprintf(command, sizeof(command), "%s -Syu --noconfirm --noprogressbar --color=never", managers[i]);

    if (run_command(command, log_fp))
    {
      update_success = true;
      break;
    }
    fprintf(log_fp, "%s update failed.\n", managers[i]);
  }

  fprintf(log_fp, update_success ? "System update completed successfully.\n" : "Update failed for all package managers.\n");

  fclose(log_fp);
  close(lock_fd);

  return update_success ? EXIT_SUCCESS : EXIT_FAILURE;
}