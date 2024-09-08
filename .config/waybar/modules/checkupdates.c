#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFER_SIZE 4096

void escape_json(const char *input, char *output, size_t size)
{
  static const char escapes[256] = {['\"'] = '\"', ['\\'] = '\\', ['\b'] = 'b', ['\f'] = 'f', ['\n'] = 'n', ['\r'] = 'r', ['\t'] = 't'};
  size_t j = 0;
  for (size_t i = 0; input[i] && j < size - 1; i++)
  {
    char ch = input[i];
    if (ch < 256 && escapes[(unsigned char)ch])
    {
      if (j + 2 < size)
      {
        output[j++] = '\\';
        output[j++] = escapes[(unsigned char)ch];
      }
    }
    else
    {
      if (j + 1 < size)
        output[j++] = ch;
    }
  }
  output[j] = '\0';
}

int main()
{
  char cmd[256];
  snprintf(cmd, sizeof(cmd), "%s/.local/bin/checkupdates", getenv("HOME"));

  char updates[BUFFER_SIZE] = {0};
  char *line = NULL;
  size_t len = 0;
  int updates_count = 0;

  FILE *fp = popen(cmd, "r");
  if (!fp)
  {
    perror("popen");
    return EXIT_FAILURE;
  }

  while (getline(&line, &len, fp) != -1)
  {
    char pkg_name[BUFFER_SIZE], local_version[BUFFER_SIZE], new_version[BUFFER_SIZE];
    if (sscanf(line, "%s %s -> %s", pkg_name, local_version, new_version) == 3)
    {
      char formatted_update[BUFFER_SIZE];
      snprintf(formatted_update, sizeof(formatted_update), "%s: %s -> %s", pkg_name, local_version, new_version);
      strncat(updates, formatted_update, sizeof(updates) - strlen(updates) - 1);
      strncat(updates, "\n", sizeof(updates) - strlen(updates) - 1);
      updates_count++;
    }
  }

  pclose(fp);
  free(line);

  size_t updates_len = strlen(updates);
  if (updates_len > 0 && updates[updates_len - 1] == '\n')
    updates[updates_len - 1] = '\0';

  char pkg_list_escaped[BUFFER_SIZE];
  escape_json(updates, pkg_list_escaped, sizeof(pkg_list_escaped));

  printf(updates_count > 0
             ? "{\"text\":\"   %d\",\"tooltip\":\"You have %d pending updates.\\n\\n%s\"}"
             : "{\"text\":\"\",\"tooltip\":\"\",\"class\":\"hidden\"}",
         updates_count, updates_count, pkg_list_escaped);

  return 0;
}