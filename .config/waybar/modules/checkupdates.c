#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>
#include <time.h>
#include <locale.h>

#define BUFFER_SIZE 4096
#define MAX_VERSION_LENGTH 20
#define MAX_UPDATES 75

typedef struct
{
  char pkg_name[BUFFER_SIZE];
  char local_version[MAX_VERSION_LENGTH + 1];
  char new_version[MAX_VERSION_LENGTH + 1];
} UpdateInfo;

void die(const char *msg)
{
  perror(msg);
  exit(EXIT_FAILURE);
}

void escape_json(const char *input, char *output, size_t size)
{
  static const char escape_chars[] = "\"\\\b\f\n\r\t";
  static const char escape_replacements[] = {'\"', '\\', 'b', 'f', 'n', 'r', 't'};
  size_t j = 0;

  for (size_t i = 0; input[i] && j < size - 1; ++i)
  {
    const char *esc = strchr(escape_chars, input[i]);
    if (esc)
    {
      if (j + 2 >= size)
        break;
      output[j++] = '\\';
      output[j++] = escape_replacements[esc - escape_chars];
    }
    else
    {
      if (j < size - 1)
        output[j++] = input[i];
    }
  }
  output[j] = '\0';
}

int compare_updates(const void *a, const void *b)
{
  return strcmp(((UpdateInfo *)a)->pkg_name, ((UpdateInfo *)b)->pkg_name);
}

int main()
{
  FILE *fp = popen("/usr/bin/checkupdates --nocolor", "r"); // Ensure 'pacman-contrib' and 'fakeroot' are installed on your system.
  if (!fp)
    die("popen failed");

  int updates_count = 0;
  UpdateInfo updates[MAX_UPDATES];

  char line[BUFFER_SIZE];
  while (fgets(line, sizeof(line), fp) != NULL && updates_count < MAX_UPDATES)
  {
    char pkg[BUFFER_SIZE], local_ver[MAX_VERSION_LENGTH + 1], new_ver[MAX_VERSION_LENGTH + 1];
    if (sscanf(line, "%s %s -> %s", pkg, local_ver, new_ver) == 3)
    {
      strncpy(updates[updates_count].pkg_name, pkg, BUFFER_SIZE - 1);
      updates[updates_count].pkg_name[BUFFER_SIZE - 1] = '\0';

      strncpy(updates[updates_count].local_version, local_ver, MAX_VERSION_LENGTH);
      updates[updates_count].local_version[MAX_VERSION_LENGTH] = '\0';

      strncpy(updates[updates_count].new_version, new_ver, MAX_VERSION_LENGTH);
      updates[updates_count].new_version[MAX_VERSION_LENGTH] = '\0';

      ++updates_count;
    }
  }

  pclose(fp);

  qsort(updates, updates_count, sizeof(UpdateInfo), compare_updates);

  char updates_str[BUFFER_SIZE * 10] = {0};
  for (int i = 0; i < updates_count; ++i)
  {
    int remaining_buffer = sizeof(updates_str) - strlen(updates_str) - 1;
    if (remaining_buffer <= 0)
      break;

    int len = snprintf(updates_str + strlen(updates_str), remaining_buffer,
                       "%-25s %s -> %s\n", updates[i].pkg_name, updates[i].local_version, updates[i].new_version);

    if (len < 0 || len >= remaining_buffer)
      break;

    if (i == MAX_UPDATES - 1 && updates_count >= MAX_UPDATES)
    {
      strncat(updates_str, "...", remaining_buffer - 1);
      break;
    }
  }

  if (updates_count > 0 && updates_str[strlen(updates_str) - 1] == '\n')
    updates_str[strlen(updates_str) - 1] = '\0';

  char pkg_list_escaped[BUFFER_SIZE * 10];
  escape_json(updates_str, pkg_list_escaped, sizeof(pkg_list_escaped));

  if (!setlocale(LC_TIME, ""))
    setlocale(LC_TIME, "C");

  time_t now = time(NULL);
  struct tm *t = localtime(&now);
  char time_str[100];
  strftime(time_str, sizeof(time_str), "%c", t);

  if (updates_count > 0)
    printf("{\"text\":\"\",\"tooltip\":\"%d updates available.\\nLast check: %s\\n\\n%s%s\"}\n", updates_count, time_str, pkg_list_escaped, (updates_count >= MAX_UPDATES ? "\\n...and more updates." : ""));
  else
    printf("{\"text\":\"\",\"tooltip\":\"You're up to date!\\nLast check: %s\"}\n", time_str);

  return 0;
}