#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define KILO 1024
#define MEGA (KILO * KILO)
#define GIGA (KILO * MEGA)

void format(long size, char *output)
{
  if (size >= GIGA)
    snprintf(output, 16, "%.2fG", (double)size / GIGA);
  else if (size >= MEGA)
    snprintf(output, 16, "%.2fM", (double)size / MEGA);
  else if (size >= KILO)
    snprintf(output, 16, "%.2fK", (double)size / KILO);
  else
    snprintf(output, 16, "%ldB", size);
}

void parse(long *mem_total, long *mem_used, long *mem_free, long *mem_shared,
           long *mem_buff_cache, long *mem_available, long *swap_total,
           long *swap_used, long *swap_free)
{
  FILE *fp = fopen("/proc/meminfo", "r");
  if (!fp)
  {
    perror("Failed to open /proc/meminfo");
    exit(EXIT_FAILURE);
  }

  char key[256];
  long value;
  *mem_total = *mem_free = *mem_shared = *mem_buff_cache = *mem_available = 0;
  *swap_total = *swap_free = 0;

  while (fscanf(fp, "%s %ld kB\n", key, &value) != EOF)
  {
    if (strcmp(key, "MemTotal:") == 0)
      *mem_total = value;
    else if (strcmp(key, "MemFree:") == 0)
      *mem_free = value;
    else if (strcmp(key, "MemAvailable:") == 0)
      *mem_available = value;
    else if (strcmp(key, "Buffers:") == 0 || strcmp(key, "Cached:") == 0)
      *mem_buff_cache += value;
    else if (strcmp(key, "Shmem:") == 0)
      *mem_shared = value;
    else if (strcmp(key, "SwapTotal:") == 0)
      *swap_total = value;
    else if (strcmp(key, "SwapFree:") == 0)
      *swap_free = value;
  }

  *mem_used = *mem_total - *mem_free - *mem_buff_cache;
  *swap_used = *swap_total - *swap_free;

  fclose(fp);
}

int main()
{
  long mem_total, mem_used, mem_free, mem_shared, mem_buff_cache, mem_available;
  long swap_total, swap_used, swap_free;

  parse(&mem_total, &mem_used, &mem_free, &mem_shared, &mem_buff_cache, &mem_available,
        &swap_total, &swap_used, &swap_free);

  char mem_usage_str[16], mem_total_str[16], mem_free_str[16], mem_shared_str[16];
  char mem_cache_str[16], mem_available_str[16], swap_usage_str[16];
  char swap_total_str[16], swap_free_str[16], total_usage_str[16];

  format(mem_used * KILO, mem_usage_str);
  format(mem_total * KILO, mem_total_str);
  format(mem_free * KILO, mem_free_str);
  format(mem_shared * KILO, mem_shared_str);
  format(mem_buff_cache * KILO, mem_cache_str);
  format(mem_available * KILO, mem_available_str);
  format(swap_used * KILO, swap_usage_str);
  format(swap_total * KILO, swap_total_str);
  format(swap_free * KILO, swap_free_str);

  format((mem_used + swap_used) * KILO, total_usage_str);

  printf("{\"text\":\"  %s\", \"tooltip\":\"Total: %s\\nFree: %s\\nAvailable: %s\\nShared: %s\\nBuffer/Cache: %s\\n\\nSwap Total: %s\\nSwap Free: %s\\nSwap Used: %s\"}",
         total_usage_str, mem_total_str, mem_free_str, mem_available_str, mem_shared_str,
         mem_cache_str, swap_total_str, swap_free_str, swap_usage_str);

  return 0;
}