#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFER_SIZE 4096

void escape_json(const char *input, char *output, size_t size)
{
  size_t j = 0;
  for (size_t i = 0; input[i] && j < size - 1; i++)
  {
    char ch = input[i];
    switch (ch)
    {
    case '\"':
    case '\\':
    case '\b':
    case '\f':
    case '\n':
    case '\r':
    case '\t':
      if (j + 2 < size)
      {
        output[j++] = '\\';
        switch (ch)
        {
        case '\"':
          output[j++] = '\"';
          break;
        case '\\':
          output[j++] = '\\';
          break;
        case '\b':
          output[j++] = 'b';
          break;
        case '\f':
          output[j++] = 'f';
          break;
        case '\n':
          output[j++] = 'n';
          break;
        case '\r':
          output[j++] = 'r';
          break;
        case '\t':
          output[j++] = 't';
          break;
        }
      }
      break;
    default:
      output[j++] = ch;
      break;
    }
  }
  output[j] = '\0';
}

int main()
{
  char cmd[BUFFER_SIZE];
  snprintf(cmd, sizeof(cmd), "%s/.local/bin/checkupdates", getenv("HOME"));

  char updates[BUFFER_SIZE] = {0};
  int updates_count = 0;

  FILE *fp = popen(cmd, "r");
  if (!fp)
  {
    perror("popen");
    return EXIT_FAILURE;
  }

  char line[BUFFER_SIZE];
  while (fgets(line, sizeof(line), fp))
  {
    char pkg_name[BUFFER_SIZE], local_version[BUFFER_SIZE], new_version[BUFFER_SIZE];
    if (sscanf(line, "%s %s -> %s", pkg_name, local_version, new_version) == 3)
    {
      int n = snprintf(updates + strlen(updates), sizeof(updates) - strlen(updates), "%s: %s -> %s\n", pkg_name, local_version, new_version);
      if (n < 0 || (size_t)n >= sizeof(updates) - strlen(updates))
        break;
      updates_count++;
    }
  }

  if (pclose(fp) == -1)
  {
    perror("pclose");
    return EXIT_FAILURE;
  }

  if (updates_count > 0 && updates[strlen(updates) - 1] == '\n')
    updates[strlen(updates) - 1] = '\0';

  char pkg_list_escaped[BUFFER_SIZE];
  escape_json(updates, pkg_list_escaped, sizeof(pkg_list_escaped));

  printf(updates_count > 0
             ? "{\"text\":\"   %d\",\"tooltip\":\"You have %d pending updates.\\n\\n%s\"}\n"
             : "{\"text\":\"\",\"tooltip\":\"\",\"class\":\"hidden\"}\n",
         updates_count, updates_count, pkg_list_escaped);

  return 0;
}