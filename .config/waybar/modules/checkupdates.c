// -lcjson

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>
#include <time.h>
#include <locale.h>
#include <limits.h>
#include <cjson/cJSON.h>

#define __DEFAULT_BUFFER_SIZE 4096
#define __DEFAULT_MAX_VERSION_LENGTH 20
#define __DEFAULT_MAX_UPDATES 75
#define MAX_CONFIG_SIZE (5 * 1024)

typedef struct
{
  int BUFFER_SIZE;
  int MAX_VERSION_LENGTH;
  int MAX_UPDATES;
} Config;

Config config;

static void set_default_config(Config *cfg)
{
  cfg->BUFFER_SIZE = __DEFAULT_BUFFER_SIZE;
  cfg->MAX_VERSION_LENGTH = __DEFAULT_MAX_VERSION_LENGTH;
  cfg->MAX_UPDATES = __DEFAULT_MAX_UPDATES;
}

static inline size_t get_file_size(FILE *file)
{
  struct stat st;
  if (fstat(fileno(file), &st) == 0)
    return st.st_size;
  return 0;
}

static char *read_file_efficient(const char *filename, size_t *size)
{
  FILE *file = fopen(filename, "rb");
  if (!file)
    return NULL;

  size_t file_size = get_file_size(file);
  if (file_size == 0 || file_size > MAX_CONFIG_SIZE)
  {
    fclose(file);
    return NULL;
  }

  char *buffer = (char *)malloc(file_size + 1);
  if (!buffer)
  {
    fclose(file);
    return NULL;
  }

  size_t bytes_read = fread(buffer, 1, file_size, file);
  fclose(file);

  if (bytes_read != file_size)
  {
    free(buffer);
    return NULL;
  }

  buffer[file_size] = '\0';
  if (size)
    *size = file_size;
  return buffer;
}

void load_config(const char *filename, Config *config)
{
  set_default_config(config);

  size_t file_size;
  char *buffer = read_file_efficient(filename, &file_size);
  if (!buffer)
    return;

  cJSON *json = cJSON_ParseWithLength(buffer, file_size);
  free(buffer);

  if (!json)
    return;

  cJSON *buffer_size = cJSON_GetObjectItem(json, "BUFFER_SIZE");
  if (cJSON_IsNumber(buffer_size) && buffer_size->valueint > 0)
    config->BUFFER_SIZE = buffer_size->valueint;

  cJSON *max_version_length = cJSON_GetObjectItem(json, "MAX_VERSION_LENGTH");
  if (cJSON_IsNumber(max_version_length) && max_version_length->valueint > 0)
    config->MAX_VERSION_LENGTH = max_version_length->valueint;

  cJSON *max_updates = cJSON_GetObjectItem(json, "MAX_UPDATES");
  if (cJSON_IsNumber(max_updates) && max_updates->valueint > 0)
    config->MAX_UPDATES = max_updates->valueint;

  cJSON_Delete(json);
}

typedef struct
{
  char pkg_name[__DEFAULT_BUFFER_SIZE];
  char local_version[__DEFAULT_MAX_VERSION_LENGTH + 1];
  char new_version[__DEFAULT_MAX_VERSION_LENGTH + 1];
} UpdateInfo;

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
  set_default_config(&config);
  char config_path[256];
  snprintf(config_path, sizeof(config_path), "%s/.config/checkupdates.json", getenv("HOME"));
  load_config(config_path, &config);

  FILE *fp = popen("/usr/bin/checkupdates --nocolor", "r");
  if (!fp)
  {
    fprintf(stderr, "Error: Failed to execute checkupdates command\n");
    return EXIT_FAILURE;
  }

  int updates_count = 0;
  UpdateInfo updates[config.MAX_UPDATES];

  char line[config.BUFFER_SIZE];
  while (fgets(line, sizeof(line), fp) != NULL && updates_count < config.MAX_UPDATES)
  {
    char pkg[config.BUFFER_SIZE], local_ver[config.MAX_VERSION_LENGTH + 1], new_ver[config.MAX_VERSION_LENGTH + 1];
    if (sscanf(line, "%s %s -> %s", pkg, local_ver, new_ver) == 3)
    {
      strncpy(updates[updates_count].pkg_name, pkg, config.BUFFER_SIZE - 1);
      updates[updates_count].pkg_name[config.BUFFER_SIZE - 1] = '\0';

      strncpy(updates[updates_count].local_version, local_ver, config.MAX_VERSION_LENGTH);
      updates[updates_count].local_version[config.MAX_VERSION_LENGTH] = '\0';

      strncpy(updates[updates_count].new_version, new_ver, config.MAX_VERSION_LENGTH);
      updates[updates_count].new_version[config.MAX_VERSION_LENGTH] = '\0';

      ++updates_count;
    }
  }

  pclose(fp);

  qsort(updates, updates_count, sizeof(UpdateInfo), compare_updates);

  char *updates_str = calloc(config.BUFFER_SIZE * 10, sizeof(char));
  if (!updates_str)
  {
    fprintf(stderr, "Error: Memory allocation failed for updates_str\n");
    return EXIT_FAILURE;
  }

  for (int i = 0; i < updates_count; ++i)
  {
    int remaining_buffer = (config.BUFFER_SIZE * 10) - strlen(updates_str) - 1;
    if (remaining_buffer <= 0)
      break;

    int len = snprintf(updates_str + strlen(updates_str), remaining_buffer,
                      "%-25s %s -> %s\n", updates[i].pkg_name, updates[i].local_version, updates[i].new_version);

    if (len < 0 || len >= remaining_buffer)
      break;

    if (i == config.MAX_UPDATES - 1 && updates_count >= config.MAX_UPDATES)
    {
      strncat(updates_str, "...", remaining_buffer - 1);
      break;
    }
  }

  if (updates_count > 0 && updates_str[strlen(updates_str) - 1] == '\n')
    updates_str[strlen(updates_str) - 1] = '\0';

  char pkg_list_escaped[config.BUFFER_SIZE * 10];
  escape_json(updates_str, pkg_list_escaped, sizeof(pkg_list_escaped));

  free(updates_str);

  if (!setlocale(LC_TIME, ""))
    setlocale(LC_TIME, "C");

  time_t now = time(NULL);
  struct tm *t = localtime(&now);
  char time_str[100];
  strftime(time_str, sizeof(time_str), "%c", t);

  if (updates_count > 0)
    printf("{\"text\":\"\",\"tooltip\":\"%d updates available.\\nLast check: %s\\n\\n%s%s\"}\n", updates_count, time_str, pkg_list_escaped, (updates_count >= config.MAX_UPDATES ? "\\n...and more updates." : ""));
  else
    printf("{\"text\":\"\",\"tooltip\":\"You're up to date!\\nLast check: %s\"}\n", time_str);

  return 0;
}