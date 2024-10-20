#include <stdio.h>
#include <stdlib.h>

#define KILO 1024
#define MEGA (KILO * KILO)
#define GIGA (KILO * MEGA)

static inline void format(long size, char *output)
{
  size *= KILO;

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

  char line[256];
  long buffers = 0, cached = 0;

  while (fgets(line, sizeof(line), fp))
  {
    if (sscanf(line, "MemTotal: %ld", mem_total) == 1)
      continue;
    if (sscanf(line, "MemFree: %ld", mem_free) == 1)
      continue;
    if (sscanf(line, "MemAvailable: %ld", mem_available) == 1)
      continue;
    if (sscanf(line, "Buffers: %ld", &buffers) == 1)
      continue;
    if (sscanf(line, "Cached: %ld", &cached) == 1)
      continue;
    if (sscanf(line, "Shmem: %ld", mem_shared) == 1)
      continue;
    if (sscanf(line, "SwapTotal: %ld", swap_total) == 1)
      continue;
    if (sscanf(line, "SwapFree: %ld", swap_free) == 1)
      continue;
  }

  fclose(fp);

  *mem_buff_cache = buffers + cached;
  *mem_used = *mem_total - *mem_available;
  *swap_used = *swap_total - *swap_free;
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

  format(mem_used, mem_usage_str);
  format(mem_total, mem_total_str);
  format(mem_free, mem_free_str);
  format(mem_shared, mem_shared_str);
  format(mem_buff_cache, mem_cache_str);
  format(mem_available, mem_available_str);
  format(swap_used, swap_usage_str);
  format(swap_total, swap_total_str);
  format(swap_free, swap_free_str);

  format(mem_used + swap_used, total_usage_str);

  double total_percentage = (double)(mem_used + swap_used) / (mem_total + swap_total) * 100;

  printf("{\"text\":\"  %s ・ %.0f%%\", \"tooltip\":\"Total ・ %s\\nUsed ・ %s\\nFree ・ %s\\nAvailable ・ %s\\nShared ・ %s\\nBuffer / Cache ・ %s\\n\\nSwap Total ・ %s\\nSwap Free ・ %s\\nSwap Used ・ %s\"}",
         total_usage_str, total_percentage, mem_total_str, mem_usage_str, mem_free_str, mem_available_str, mem_shared_str,
         mem_cache_str, swap_total_str, swap_free_str, swap_usage_str);

  return 0;
}