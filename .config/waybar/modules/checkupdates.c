#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFER_SIZE 4096

char *exec_command(const char *command)
{
  char buffer[BUFFER_SIZE];
  char *result = NULL;
  size_t len = 0;
  FILE *fp = popen(command, "r");
  if (!fp)
  {
    perror("popen");
    return NULL;
  }
  while (fgets(buffer, sizeof(buffer), fp))
  {
    size_t buffer_len = strlen(buffer);
    char *new_result = realloc(result, len + buffer_len + 1);
    if (!new_result)
    {
      perror("realloc");
      free(result);
      pclose(fp);
      return NULL;
    }
    result = new_result;
    memcpy(result + len, buffer, buffer_len);
    len += buffer_len;
    result[len] = '\0';
  }
  pclose(fp);
  return result;
}

void escape_json(const char *input, char *output, size_t output_size)
{
  static const char escapes[256] = {
      ['\"'] = '\"', ['\\'] = '\\', ['\b'] = 'b', ['\f'] = 'f', ['\n'] = 'n', ['\r'] = 'r', ['\t'] = 't'};
  size_t i, j = 0;
  for (i = 0; i < strlen(input) && j < output_size - 1; i++)
  {
    char ch = input[i];
    if (ch < 256 && escapes[(unsigned char)ch])
    {
      if (j + 2 < output_size)
      {
        output[j++] = '\\';
        output[j++] = escapes[(unsigned char)ch];
      }
    }
    else
    {
      output[j++] = ch;
    }
  }
  output[j] = '\0';
}

int main()
{
  char *updates = exec_command("checkupdates --nocolor");
  if (!updates || strlen(updates) < 2)
    return 1;

  int updates_count = 0;
  char pkg_list[BUFFER_SIZE] = {0};
  char *line = strtok(updates, "\n");
  while (line)
  {
    updates_count++;
    char pkg_info[BUFFER_SIZE];
    char pkg_name[BUFFER_SIZE];
    char pkg_version_current[BUFFER_SIZE];
    char ok[BUFFER_SIZE];
    char pkg_version_new[BUFFER_SIZE];

    if (sscanf(line, "%s %s %s %s", pkg_name, pkg_version_current, ok, pkg_version_new) == 4)
    {
      snprintf(pkg_info, sizeof(pkg_info), "%s: %s %s %s", pkg_name, pkg_version_current, ok, pkg_version_new);
      if (strlen(pkg_list) > 0)
        strncat(pkg_list, "\n", sizeof(pkg_list) - strlen(pkg_list) - 1);
      strncat(pkg_list, pkg_info, sizeof(pkg_list) - strlen(pkg_list) - 1);
    }

    line = strtok(NULL, "\n");
  }

  free(updates);

  char pkg_list_escaped[BUFFER_SIZE];
  escape_json(pkg_list, pkg_list_escaped, sizeof(pkg_list_escaped));

  printf(updates_count > 0
             ? "{\"text\":\"   %d\",\"tooltip\":\"You have %d pending updates.\\n\\n%s\"}"
             : "{\"text\":\"\",\"tooltip\":\"\",\"class\":\"hidden\"}",
         updates_count, updates_count, pkg_list_escaped);

  return 0;
}