#!/usr/bin/env ruby
# frozen_string_literal: true

# Idempotently inject GA4 into static research HTML under public/research/.
# Aligns measurement ID with frontend prod + Rails (_meta_tags GA4).
# Consent defaults match Angular when cookie UI is disabled (analytics_storage granted).

ROOT = File.expand_path("..", __dir__)
RESEARCH_DIR = File.join(ROOT, "public", "research")
MEASUREMENT_ID = "G-WNLSL6W4ZT"

MARKER_START = "<!-- agrr-research-ga:start -->"
MARKER_END = "<!-- agrr-research-ga:end -->"

SNIPPET = <<~HTML.strip
  #{MARKER_START}
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag() { dataLayer.push(arguments); }
    gtag("consent", "default", {
      ad_storage: "denied",
      ad_user_data: "denied",
      ad_personalization: "denied",
      analytics_storage: "granted",
      functionality_storage: "granted",
      security_storage: "granted",
      wait_for_update: 500
    });
  </script>
  <script async src="https://www.googletagmanager.com/gtag/js?id=#{MEASUREMENT_ID}"></script>
  <script>
    gtag("js", new Date());
    gtag("config", "#{MEASUREMENT_ID}", {
      anonymize_ip: true,
      cookie_flags: "SameSite=None;Secure",
      send_page_view: false
    });
    function agrrResearchTrackPageView() {
      if (typeof gtag !== "function") return;
      gtag("event", "page_view", {
        page_path: window.location.pathname + window.location.search,
        anonymize_ip: true
      });
    }
    document.addEventListener("DOMContentLoaded", function () {
      agrrResearchTrackPageView();
    });
    (function () {
      function wrap(method) {
        var orig = history[method];
        if (typeof orig !== "function") return;
        history[method] = function () {
          var rv = orig.apply(this, arguments);
          setTimeout(agrrResearchTrackPageView, 0);
          return rv;
        };
      }
      wrap("pushState");
      wrap("replaceState");
      window.addEventListener("popstate", function () {
        setTimeout(agrrResearchTrackPageView, 0);
      });
    })();
  </script>
  #{MARKER_END}
HTML

unless Dir.exist?(RESEARCH_DIR)
  warn "[inject-research-google-analytics] skip: #{RESEARCH_DIR} missing"
  exit 0
end

paths = Dir.glob(File.join(RESEARCH_DIR, "**", "*.html"))
updated = 0

paths.each do |path|
  html = File.read(path, encoding: "UTF-8")
  new_html =
    if html.include?(MARKER_START)
      unless html.include?(MARKER_END)
        warn "[inject-research-google-analytics] broken markers: #{path}"
        next
      end
      html.sub(
        /#{Regexp.escape(MARKER_START)}.*?#{Regexp.escape(MARKER_END)}/m,
        SNIPPET
      )
    elsif html.match?(%r{</head>}i)
      html.sub(%r{</head>}i, "#{SNIPPET}\n</head>")
    else
      warn "[inject-research-google-analytics] skip (no </head>): #{path}"
      next
    end

  next if new_html == html

  File.write(path, new_html)
  updated += 1
end

puts "[inject-research-google-analytics] processed #{paths.size} HTML file(s), updated #{updated}"
