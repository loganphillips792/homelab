// Switch service links between Caddy URLs (http://<name>.homelab) and direct
// IP:port URLs (http://<this host>:<port>). Defaults to Caddy when Homepage itself
// is opened via a .homelab name, and to direct otherwise (e.g. http://192.168.1.150:3002),
// so links keep working when Pi-hole DNS is down. The button bottom-right overrides
// the default; the choice is remembered per browser.
//
// Keep PORTS in sync with the host ports in the compose files when a service is
// added or moved. Hosts not listed here are left as Caddy URLs.
(() => {
  const PORTS = {
    akhq: 8092,
    backrest: 9898,
    beszel: 8090,
    cadvisor: 8089,
    changedetection: 5050,
    cronmaster: 40123,
    "cta-map": 8087,
    dockhand: 3001,
    dozzle: 8083,
    drawio: 8080,
    dynacat: 8085,
    excalidraw: 5080,
    flame: 5005,
    forgejo: 3014,
    gatus: 8082,
    glance: 8084,
    grafana: 3013,
    hermes: 9119,
    homeassistant: 8123,
    homepage: 3002,
    immich: 2283,
    jellyfin: 8096,
    jotty: 1122,
    "kafka-ui": 8091,
    karakeep: 3012,
    linkwarden: 3000,
    "live-auction": 8086,
    loki: 3100,
    matomo: 8093,
    metabase: 3010,
    n8n: 5678,
    navidrome: 4533,
    netdata: 19999,
    ollama: 7869,
    "ollama-webui": 8081,
    paperless: 8001,
    penpot: 9001,
    pihole: 8088,
    pinchflat: 8945,
    planka: 1337,
    prometheus: 9090,
    redisinsight: 5540,
    rustfs: 9031,
    "rustfs-s3": 9030,
    silo: 9011,
    "silo-s3": 9010,
    tubearchivist: 8000,
    umami: 3011,
    "uptime-kuma": 3004,
    vaults3: 9020,
    zigbee2mqtt: 8095,
  };

  const KEY = "homelab-link-mode";
  const ORIG = "data-caddy-href";
  const openedViaCaddy = location.hostname.endsWith(".homelab");

  const readMode = () => {
    try {
      const saved = localStorage.getItem(KEY);
      if (saved === "caddy" || saved === "direct") return saved;
    } catch {}
    return openedViaCaddy ? "caddy" : "direct";
  };

  let mode = readMode();

  // Use whatever IP Homepage was opened on; when opened via a .homelab name there
  // is no IP to borrow, so use the VM's.
  const directHost = openedViaCaddy ? "192.168.1.150" : location.hostname;

  const toDirect = (href) => {
    let url;
    try {
      url = new URL(href);
    } catch {
      return null;
    }
    const m = url.hostname.match(/^([a-z0-9-]+)\.homelab$/);
    if (!m || !(m[1] in PORTS)) return null;
    url.hostname = directHost;
    url.port = String(PORTS[m[1]]);
    return url.toString();
  };

  const apply = (a) => {
    const original = a.getAttribute(ORIG) || a.getAttribute("href");
    if (!original) return;
    const direct = toDirect(original);
    if (!direct) return;
    if (!a.hasAttribute(ORIG)) a.setAttribute(ORIG, original);
    const want = mode === "direct" ? direct : original;
    if (a.getAttribute("href") !== want) a.setAttribute("href", want);
  };

  const applyAll = () => document.querySelectorAll("a[href]").forEach(apply);

  // Homepage renders client-side, so re-apply as links appear or get re-rendered.
  new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === "attributes") {
        // An href that is neither of our two values came from a React re-render;
        // treat it as the new original.
        const cur = m.target.getAttribute("href");
        const orig = m.target.getAttribute(ORIG);
        if (orig && cur !== orig && cur !== toDirect(orig)) m.target.removeAttribute(ORIG);
        apply(m.target);
      } else {
        m.addedNodes.forEach((n) => {
          if (n.nodeType !== 1) return;
          if (n.matches("a[href]")) apply(n);
          n.querySelectorAll("a[href]").forEach(apply);
        });
      }
    }
  }).observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["href"],
  });

  const button = document.createElement("button");
  const label = () => {
    button.textContent = mode === "direct" ? "Links: IP:port" : "Links: .homelab";
    button.title = "Switch between Caddy (.homelab) and direct IP:port links";
  };
  Object.assign(button.style, {
    position: "fixed",
    right: "12px",
    bottom: "12px",
    zIndex: 1000,
    padding: "6px 10px",
    borderRadius: "6px",
    border: "1px solid rgba(255,255,255,0.2)",
    background: "rgba(0,0,0,0.5)",
    color: "#fff",
    font: "12px sans-serif",
    cursor: "pointer",
  });
  button.addEventListener("click", () => {
    mode = mode === "direct" ? "caddy" : "direct";
    try {
      localStorage.setItem(KEY, mode);
    } catch {}
    label();
    applyAll();
  });
  label();
  document.body.appendChild(button);
  applyAll();
})();
