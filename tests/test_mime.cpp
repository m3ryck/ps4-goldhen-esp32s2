#include <cassert>
#include <cstring>
#include "mime.h"

int main() {
  assert(std::strcmp(contentTypeFor("/jb.js"), "text/javascript") == 0);
  assert(std::strcmp(contentTypeFor("/cache.appcache"), "text/cache-manifest") == 0);
  assert(std::strcmp(contentTypeFor("/goldhen.bin"), "application/octet-stream") == 0);
  assert(std::strcmp(contentTypeFor("/style.css"), "text/css") == 0);
  assert(std::strcmp(contentTypeFor("/index.html"), "text/html") == 0);
  assert(std::strcmp(contentTypeFor("/meme.png"), "image/png") == 0);
  assert(std::strcmp(cacheControlFor("/meme.png"), "public, max-age=604800") == 0);
  assert(std::strcmp(cacheControlFor("/jb.js"), "no-cache, must-revalidate") == 0);
  return 0;
}
