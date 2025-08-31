# pillar/application/homepage.sls

homepage:
  title: "Vlot Ltd Homelab"
  theme: "dark"
  color: "slate"
  
  # Widget configuration
  logo_url: "https://avatars.githubusercontent.com/u/1818869?s=400&u=4670671282b7bbb00087c6acf361cd850ec07adf&v=4"
  search_provider: "duckduckgo"  # google, duckduckgo, bing, baidu, brave, custom
  search_target: "_blank"
  date_style: "long"  # full, long, medium, short
  time_style: "long"  # full, long, medium, short  
  hour12: false
  show_resources: true
  show_cpu: true
  show_memory: true
  show_uptime: false
  show_network: false
  disk_path: "/"
  network_interface: "eth0"
  
  # Optional custom widgets
  custom_widgets:
    - type: "greeting"
      config:
        text_size: "xl"
        text: "Welcome to your Entertainment Hub"
  
  # Service definitions - fully data-driven
  service_groups:
    main_services:
      title: "Main Services"
      layout:
        style: "row"
        columns: 3
        header: true
      services:
        grafana:
          name: "Grafana"
          icon: "grafana.png"
          description: "Grafana"
          host_lookup: "zabbix"  # Use zabbix host from pillar
          port: 3000
          widget:
            type: "grafana"
            username_vault_path: "secret/data/grafana"
            username_vault_key: "username"
            password_vault_path: "secret/data/grafana"
            password_vault_key: "admin_password"
            
        heimdall2:
          name: "Heimdall2"
          icon: "heimdall.png"
          description: "Heimdall2 Security Overview"
          host_lookup: "docker"
          port: 8080
          
        home_assistant:
          name: "Home Assistant"
          icon: "home-assistant.png"
          description: "Home Assistant"
          host_lookup: "homeassistant"
          port: 32400
          
        plex:
          name: "Plex"
          icon: "plex-alt-light.png"
          description: "Plex Media Server"
          host_lookup: "plex"
          port: 32400
          
        vault:
          name: "Vault"
          icon: "vault.png"
          description: "Hashicorp Vault"
          host_lookup: "vault"
          port: 8200
          
        zabbix:
          name: "Zabbix"
          icon: "zabbix.png"
          description: "Zabbix"
          host_lookup: "zabbix"
          path: "/zabbix/"
          widget:
            type: "zabbix"
            username_vault_path: "secret/data/zabbix"
            username_vault_key: "username"
            password_vault_path: "secret/data/zabbix"
            password_vault_key: "admin_password"

    infrastructure:
      title: "Infrastructure"
      layout:
        style: "row"
        columns: 5
        header: true
      services:
        proxmox:
          name: "Proxmox"
          icon: "proxmox.png"
          description: "Proxmox Cluster"
          host_lookup: "proxmox"
          port: 8006
          protocol: "https"
          widget:
            type: "proxmox"
            username_vault_path: "secret/data/proxmox"
            username_vault_key: "homepage_username"
            password_vault_path: "secret/data/proxmox"
            password_vault_key: "homepage_password"
            node: "proxmox"
            
        truenas:
          name: "TrueNas"
          icon: "truenas.png"
          description: "TrueNas Storage"
          host_lookup: "truenas"
          protocol: "https"
          widget:
            type: "truenas"
            api_key_vault_path: "secret/data/truenas"
            api_key_vault_key: "api_key"
            enablePools: true
            
        virgin_network:
          name: "Virgin Network"
          icon: "si-virgin.svg"
          description: "Virgin Media Network"
          static_ip: "192.168.0.1"
          
        creality_k1:
          name: "Creality K1 Rooted"
          icon: "octoprint.png"
          description: "Creality K1"
          static_ip: "192.168.0.172"
          port: 4408
          
        desk_kvm:
          name: "Desk KVM"
          icon: "pigallery2.png"
          description: "Desk KVM"
          static_ip: "192.168.0.148"
          path: "/#/"
          
        proxmox_kvm:
          name: "Proxmox KVM"
          icon: "proxmox-light.png"
          description: "Proxmox KVM"
          static_ip: "192.168.0.141"
          
        fing:
          name: "Fing"
          icon: "mdi-wifi-#f0d453"
          description: "Fing Network Monitoring"
          static_url: "https://app.fing.com/web"

    other_services:
      title: "Other Services"
      layout:
        style: "row"
        columns: 1
        header: true
      services:
        homebox:
          name: "Homebox"
          icon: "homebox.png"
          description: "Homebox Storage Management"
          host_lookup: "docker"
          port: 3100
          widget:
            type: "homebox"

    web_services:
      title: "Web Based Services"
      layout:
        style: "row"
        columns: 5
        header: true
      services:
        tailscale:
          name: "Tailscale"
          icon: "tailscale-light.png"
          description: "Tailscale"
          static_url: "https://login.tailscale.com/admin/machines"
          
        github:
          name: "Github"
          icon: "github-light.png"
          description: "Github"
          static_url: "https://github.com/belnarlo?tab=repositories"
          
        wakatime:
          name: "WakaTime"
          icon: "wakatime-light.png"
          description: "Coding stats"
          static_url: "https://wakatime.com/dashboard"

  # Entertainment RSS feeds
  entertainment:
    movie_releases:
      title: "Entertainment Releases"
      layout:
        style: "row"
        columns: 2
      feeds:
        dvd_bluray:
          name: "DVD & Blu-ray Releases"
          icon: "mdi-disc"
          url: "https://www.dvdsreleasedates.com/rss.xml"
          href: "https://www.dvdsreleasedates.com/"
          limit: 5
          
        bluray_weekly:
          name: "Blu-ray.com Weekly"
          icon: "mdi-disc-player"
          url: "https://www.blu-ray.com/rss/newreleasesfeed.xml"
          href: "https://www.blu-ray.com/movies/releasedates.php"
          limit: 5
          
        movie_insider:
          name: "Movie Insider Releases"
          icon: "mdi-movie"
          url: "https://www.movieinsider.com/rss/movies-in-theaters.rss"
          href: "https://www.movieinsider.com/movies/in-theaters"
          limit: 5
      
      # API-based services
      api_services:
        tmdb:
          name: "TMDB Upcoming Movies"
          icon: "mdi-movie-star"
          href: "https://www.themoviedb.org/movie/upcoming"
          description: "TMDB upcoming releases"
          vault_path: "secret/data/homepage"
          vault_key: "tmdb_api_key"
          api_url: "https://api.themoviedb.org/3/movie/upcoming"
          api_header: "Authorization"
          api_header_prefix: "Bearer "
    
    game_releases:
      title: "Game Releases"
      layout:
        style: "row"
        columns: 3
      feeds:
        xbox_wire:
          name: "Xbox Wire News"
          icon: "mdi-microsoft-xbox"
          url: "https://news.xbox.com/en-us/feed/"
          href: "https://news.xbox.com/"
          limit: 6
          
        xbox_gamepass:
          name: "Xbox Game Pass Updates"
          icon: "mdi-xbox"
          url: "https://majornelson.com/feed/"
          href: "https://www.xbox.com/en-GB/xbox-game-pass/games/coming-soon"
          limit: 5
          
        steam_releases:
          name: "Steam New Releases"
          icon: "mdi-steam"
          url: "https://store.steampowered.com/feeds/newreleases.xml"
          href: "https://store.steampowered.com/explore/new/"
          limit: 6
          
        pc_gaming:
          name: "PC Gaming News"
          icon: "mdi-gamepad-variant"
          url: "https://www.pcgamer.com/rss/"
          href: "https://www.pcgamer.com/"
          limit: 5
      
      # Custom API services
      custom_services:
        xbox_tracker:
          name: "Xbox Game Pass Tracker"
          icon: "mdi-microsoft-xbox"
          href: "https://www.xbox.com/en-GB/xbox-game-pass/games/coming-soon"
          description: "Xbox Game Pass releases via custom tracker"
          api_url: "http://steam-tracker:5000/xbox-gamepass"
          
        steam_wishlist:
          name: "Steam Wishlist"
          icon: "mdi-steam"
          href: "https://store.steampowered.com/wishlist/"
          description: "Your Steam wishlist updates"
          api_url: "http://steam-tracker:5000/wishlist"
          vault_path: "secret/data/homepage"
          vault_key: "steam_api_key"