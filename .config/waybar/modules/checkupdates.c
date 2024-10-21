#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

#define BUFFER_SIZE 4096
#define MAX_VERSION_LENGTH 20

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
      output[j++] = input[i];
  }
  output[j] = '\0';
}

int compare_updates(const void *a, const void *b)
{
  return strcmp(((UpdateInfo *)a)->pkg_name, ((UpdateInfo *)b)->pkg_name);
}

int main()
{
  FILE *fp = popen("/usr/bin/checkupdates --nocolor", "r"); // Check 'pacman-contrib' and 'fakeroot' is installed on your system.
  if (!fp)
    die("popen failed");

  int updates_count = 0, updates_capacity = 16;
  UpdateInfo *updates = malloc(updates_capacity * sizeof(UpdateInfo));
  if (!updates)
    die("malloc failed");

  char line[BUFFER_SIZE];
  while (fgets(line, sizeof(line), fp) != NULL)
  {
    if (updates_count == updates_capacity)
    {
      updates_capacity *= 2;
      UpdateInfo *temp = realloc(updates, updates_capacity * sizeof(UpdateInfo));
      if (!temp)
        die("realloc failed");
      updates = temp;
    }

    char pkg[BUFFER_SIZE], local_ver[MAX_VERSION_LENGTH + 1], new_ver[MAX_VERSION_LENGTH + 1];
    if (sscanf(line, "%s %s -> %s", pkg, local_ver, new_ver) == 3)
    {
      strncpy(updates[updates_count].pkg_name, pkg, BUFFER_SIZE - 1);
      strncpy(updates[updates_count].local_version, local_ver, MAX_VERSION_LENGTH);
      strncpy(updates[updates_count].new_version, new_ver, MAX_VERSION_LENGTH);
      ++updates_count;
    }
  }

  pclose(fp);

  qsort(updates, updates_count, sizeof(UpdateInfo), compare_updates);

  char updates_str[BUFFER_SIZE * 10] = {0};
  for (int i = 0; i < updates_count; ++i)
    snprintf(updates_str + strlen(updates_str), sizeof(updates_str) - strlen(updates_str),
             "%-25s %s -> %s\n", updates[i].pkg_name, updates[i].local_version, updates[i].new_version);

  if (updates_count > 0 && updates_str[strlen(updates_str) - 1] == '\n')
    updates_str[strlen(updates_str) - 1] = '\0';

  char pkg_list_escaped[BUFFER_SIZE * 10];
  escape_json(updates_str, pkg_list_escaped, sizeof(pkg_list_escaped));

  printf(updates_count > 0
             ? "{\"text\":\"   %d\",\"tooltip\":\"You have %d pending updates.\\n\\n%s\"}\n"
             : "{\"text\":\" \",\"tooltip\":\"You're up to date!\"}\n",
         updates_count, updates_count, pkg_list_escaped);

  free(updates);
  return 0;
}
