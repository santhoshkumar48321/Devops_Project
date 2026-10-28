# InfraReaper — Monitoring & Observability Architecture

This document details the telemetry, metrics pipeline, logging infrastructure, and dashboard specifications powering InfraReaper.

---

## 🏗️ Observability Stack Architecture

InfraReaper relies on a decoupled, cloud-native monitoring architecture:

1. **Prometheus Pushgateway (Port 9091)**: Accepts metric pushes from short-lived batch CronJob pods that cannot be directly scraped.
2. **Prometheus Core (Port 9090)**: Scrapes Pushgateway every 15 seconds with `honor_labels: true`, evaluating alerting rules and persisting time-series data.
3. **Alertmanager (Port 9093)**: Dispatches governance violation alerts and scanner SLO breaches.
4. **Grafana Loki (Port 3100)**: Ingests unstructured and structured logs from Promtail.
5. **Promtail (DaemonSet)**: Ships pod stdout/stderr logs from `/var/log/pods` to Loki.
6. **Grafana (Port 3000)**: Visualizes telemetry across 6 pre-provisioned dashboards.

---

## 📈 Complete Metrics Dictionary

| Metric Name | Type | Labels | Description |
|---|---|---|---|
| `infrareaper_scan_total` | Counter | `environment` | Total scan runs executed |
| `infrareaper_scan_success_total` | Counter | `environment` | Total successful scan runs (used for SLO calculations) |
| `infrareaper_scan_duration_seconds` | Gauge | `environment` | Total execution time of last scan in seconds |
| `infrareaper_resources_total` | Gauge | `environment` | Total cloud assets discovered in target resource groups |
| `infrareaper_compliant_resources_total` | Gauge | `environment` | Count of assets complying with mandatory tagging policies |
| `infrareaper_noncompliant_resources_total`| Gauge | `environment` | Count of assets violating tagging policies |
| `infrareaper_compliance_score` | Gauge | `environment` | Governance compliance score percentage (0–100%) |
| `infrareaper_violations_total` | Gauge | `environment`, `severity` | Violations categorized by `CRITICAL`, `WARNING`, `INFO` |
| `infrareaper_orphaned_resources_total` | Gauge | `environment` | Total orphaned assets (unattached disks, unassociated IPs) |
| `infrareaper_expiring_resources_total` | Gauge | `environment`, `window` | Resources expiring within `7d`, `72h`, or `24h` windows |
| `infrareaper_expired_resources_total` | Gauge | `environment`, `state` | Assets in `grace_period` (48h) or `actionable` state |
| `infrareaper_cleaned_resources_total` | Gauge | `environment`, `mode` | Resources purged during cleanup in `real` or `dry_run` mode |

---

## 📊 Overview of the 6 Production Dashboards

### 1. Scanner SLO & Availability (`infrareaper-slo`)
- **SLO Target**: 99.0% availability over rolling 24-hour windows.
- **Availability Gauge**: `clamp_max((sum(infrareaper_scan_success_total) / clamp_min(sum(infrareaper_scan_total), 1)) * 100, 100)`.
- **Error Budget**: Tracks remaining error budget percentage and burn rate before SLO violation.
- **Duration Metrics**: P95 and average execution latency trends.

### 2. Tag & Policy Governance Compliance (`infrareaper-compliance`)
- **Overall Score**: Visual stat gauge (<50% Red, 50-80% Yellow, >80% Green).
- **Compliant vs Non-Compliant**: Resource count comparison.
- **Severity Breakdown**: Stacked bar chart of Critical, Warning, and Info policy violations.
- **Compliance History**: Trend line tracking improvement over time.

### 3. Cloud Resource Inventory (`infrareaper-inventory`)
- **Total Discovered Assets**: High-level inventory tally across Azure subscriptions.
- **Orphan Count**: Standalone counter for zombie infrastructure.
- **Compliance Ratio**: Donut pie chart displaying tagged vs non-compliant resource ratios.

### 4. Resource Lifecycle & Expiry States (`infrareaper-lifecycle`)
- **Warning Windows**: Counts of resources expiring within 7 days, 72 hours, and 24 hours.
- **Grace Period Pipeline**: Resources currently in the 48-hour deallocation grace window.
- **Actionable Cleanup Targets**: Assets past grace period ready for automated deletion.
- **Audit Stats**: Cleanups simulated in dry-run mode vs real purges executed.

### 5. Cloud Cost & Waste Attribution (`infrareaper-cost`)
- **Estimated Monthly Waste**: Calculates preventable dollar waste based on unattached disks ($10/mo) and unused IPs ($3.65/mo).
- **FinOps Savings**: Quantifies projected cloud bill reductions achieved through automated hygiene sweeps.

### 6. Scanner System Health & Logs (`infrareaper-health`)
- **Component Status**: Direct health checks for Pushgateway (`up{job="pushgateway"}`) and Prometheus.
- **Real-Time LogQL Terminal**: Live stream of scanner pod stdout/stderr logs from Loki:
  ```logql
  {namespace="infrareaper"}
  ```

---

## 🚨 Alerting Rules Baseline

Prometheus evaluates alerting rules continuously against ingested telemetry:

- **`InfraReaperLowCompliance`**: Triggers warning if `infrareaper_compliance_score < 50` for > 5 minutes.
- **`InfraReaperCriticalViolationsHigh`**: Triggers critical alert if `infrareaper_violations_total{severity="CRITICAL"} > 5`.
- **`InfraReaperSLOBreach`**: Triggers critical alert if 1-hour scan success rate drops below 99.0%.
- **`InfraReaperPushgatewayDown`**: Triggers warning if Pushgateway endpoint is unreachable for > 5 minutes.

