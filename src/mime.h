#pragma once
#include <cstring>

inline bool endsWith(const char* s, const char* suffix) {
  size_t ls = std::strlen(s);
  size_t lf = std::strlen(suffix);
  return ls >= lf && std::strcmp(s + ls - lf, suffix) == 0;
}

inline const char* contentTypeFor(const char* path) {
  if (endsWith(path, ".html"))     return "text/html";
  if (endsWith(path, ".css"))      return "text/css";
  if (endsWith(path, ".js"))       return "text/javascript";
  if (endsWith(path, ".appcache")) return "text/cache-manifest";
  if (endsWith(path, ".png"))      return "image/png";
  if (endsWith(path, ".bin"))      return "application/octet-stream";
  return "application/octet-stream";
}

inline const char* cacheControlFor(const char* path) {
  if (endsWith(path, ".png")) return "public, max-age=604800";
  return "no-cache, must-revalidate";
}
