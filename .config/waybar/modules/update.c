#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>

#define LOG_FILE "/var/tmp/update.log"
#define LOCK_FILE "/var/tmp/update.lock"
#define COMMAND_SIZE 256

const char *managers[] = {"yay", "paru", "pacman"};

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

  return pclose(fp) == 0;
}

int main()
{
  if (geteuid() != 0)
  {
    fprintf(stderr, "This script requires root privileges.\n");
    return EXIT_FAILURE;
  }

  if (access(LOCK_FILE, F_OK) == 0)
  {
    fprintf(stderr, "Another instance of the script is running.\n");
    return EXIT_FAILURE;
  }

  FILE *log_fp = fopen(LOG_FILE, "w");
  if (!log_fp)
  {
    perror("fopen");
    return EXIT_FAILURE;
  }

  FILE *lock_fp = fopen(LOCK_FILE, "w");
  if (!lock_fp)
  {
    perror("fopen");
    fclose(log_fp);
    return EXIT_FAILURE;
  }

  bool update_success = 0;
  for (size_t i = 0; i < (sizeof(managers) / sizeof(managers[0])); ++i)
  {
    char command[COMMAND_SIZE];
    snprintf(command, sizeof(command), "%s -Syu --noconfirm --noprogressbar --color=never", managers[i]);

    if (run_command(command, log_fp))
    {
      update_success = 1;
      break;
    }
    fprintf(log_fp, "%s update failed. Check the log for details.\n", managers[i]);
  }

  fprintf(log_fp, update_success ? "System update completed successfully.\n" : "Update failed. No known package manager found or all updates failed.\n");

  fclose(log_fp);
  fclose(lock_fp);
  remove(LOCK_FILE);

  return EXIT_SUCCESS;
}