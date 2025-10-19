docker:
  host_tailscale_ip: 100.73.13.74
  services:
    alertmanager:
      port: 9093
      container: alertmanager
    heimdall2:
      port: 8080
      container: heimdall2
    homebox:
      port: 3100
      container: homebox
    homepage:
      port: 3000
      container: homepage
    linkwarden:
      port: 3200
      container: linkwarden
    loki:
      port: 3100
      container: loki
    portainer:
      port: 9000
      container: portainer
    prometheus:
      port: 9090
      container: prometheus
    webdriver:
      port: 4444
      container: webdriver