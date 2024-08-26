#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

#define LOG_FILE "/var/tmp/update.log"
#define MANAGERS_COUNT 3
#define COMMAND_SIZE 256

const char *managers[MANAGERS_COUNT] = {"yay", "pacman", "paru"};

bool run_command(const char *command, FILE *log_fp)
{
  FILE *fp = popen(command, "r");
  if (!fp)
  {
    perror("popen");
    return 0;
  }

  char buffer[COMMAND_SIZE];
  while (fgets(buffer, sizeof(buffer), fp))
    fputs(buffer, log_fp);

  int status = pclose(fp);
  return (status == 0);
}

int main()
{
  if (geteuid() != 0)
  {
    fprintf(stderr, "This script requires root privileges.\n");
    return EXIT_FAILURE;
  }

  FILE *log_fp = fopen(LOG_FILE, "w");
  if (!log_fp)
  {
    perror("fopen");
    return EXIT_FAILURE;
  }

  bool update_success = 0;

  for (int i = 0; i < MANAGERS_COUNT; ++i)
  {
    char command[COMMAND_SIZE];
    snprintf(command, sizeof(command), "%s -Syu --noconfirm --noprogressbar 2>&1", managers[i]);

    if (run_command(command, log_fp))
    {
      update_success = 1;
      break;
    }
    fprintf(log_fp, "%s update failed. Check the log for details.\n", managers[i]);
  }

  if (update_success)
    fprintf(log_fp, "System update completed successfully.\n");
  else
    fprintf(log_fp, "No known package manager found or all updates failed.\nUpdate failed.\n");

  fclose(log_fp);
  return EXIT_SUCCESS;
}