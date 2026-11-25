#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <LittleFS.h>
#include <ESPmDNS.h>
#include "config.h"
#include "mime.h"

static WebServer server(80);
static DNSServer dnsServer;

static String stripQuery(const String &uri) {
  int q = uri.indexOf('?');
  return q >= 0 ? uri.substring(0, q) : uri;
}

static bool serveFile(const String &path) {
  String p = path;
  if (p.length() == 0 || p == "/") p = "/index.html";
  if (!LittleFS.exists(p)) return false;
  File f = LittleFS.open(p, "r");
  if (!f) return false;
  server.sendHeader("Cache-Control", cacheControlFor(p.c_str()));
  server.streamFile(f, contentTypeFor(p.c_str()));
  f.close();
  return true;
}

void setup() {
  Serial.begin(115200);

  if (!LittleFS.begin(false)) {
    Serial.println("LittleFS mount failed; reiniciando");
    delay(2000);
    ESP.restart();
  }

  IPAddress apIP(10, 1, 1, 1);
  IPAddress apMask(255, 255, 255, 0);
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(apIP, apIP, apMask);
  WiFi.softAP(WIFI_SSID, WIFI_PASS);
  delay(200);
  Serial.printf("[%s] AP '%s' em http://%s/\n", FW_LABEL, WIFI_SSID, apIP.toString().c_str());

  dnsServer.start(53, "*", apIP);

  if (MDNS.begin(HOSTNAME)) {
    MDNS.addService("http", "tcp", 80);
  }

  server.on("/", []() { serveFile("/index.html"); });
  server.onNotFound([]() {
    String path = stripQuery(server.uri());
    if (!serveFile(path)) {
      server.sendHeader("Location", "http://10.1.1.1/");
      server.send(302, "text/plain", "");
    }
  });

  server.begin();
}

void loop() {
  dnsServer.processNextRequest();
  server.handleClient();
  delay(1);
}
