#!/usr/bin/env bash
# VSF helper — jalankan dari host (Mac), bukan dari dalam container.
#
#   ./vsf.sh new            Nyalakan container, buat eksperimen baru, join semua worker, set .env viewer
#   ./vsf.sh join [ID]      Join semua worker ke eksperimen yang sudah ada (default: yang terbaru)
#   ./vsf.sh work [--live]  Mulai sesi kunjungan manual di userdiff_worker1 (lihat browser via VNC :55905)
#   ./vsf.sh viewer         Jalankan request-viewer (http://localhost:3000)
#   ./vsf.sh status         Tampilkan container, daftar eksperimen, dan isi tabel utama
#   ./vsf.sh stop           Hentikan proses eksperimen di semua worker
set -euo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEWER_DIR="$FRAMEWORK_DIR/../request-viewer"
WORKERS="userdiff_auto userdiff_worker1 swap_auto"

cd "$FRAMEWORK_DIR"

log() { printf '\033[1;34m[vsf]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[vsf]\033[0m %s\n' "$*" >&2; exit 1; }

dc() { docker compose "$@"; }
psql_db() { dc exec -T crawler-db psql -U postgres -Atc "$1"; }

up() {
  log "Menyalakan container..."
  dc up -d crawler-db $WORKERS
  log "Menunggu database siap..."
  for _ in $(seq 1 30); do
    dc exec -T crawler-db pg_isready -U postgres >/dev/null 2>&1 && return 0
    sleep 2
  done
  die "Database tidak siap setelah 60 detik."
}

latest_experiment() {
  psql_db "select datname from pg_database where datname like 'userdiff_manual___%' order by datname desc limit 1"
}

join_worker() { # $1=service $2=db_name
  local service=$1 db=$2 ts
  ts=${db#userdiff_manual___}
  log "Join $service -> $db"
  # experiment-join mencoba CREATE DATABASE; error "already exists" aman diabaikan.
  dc exec -T -w /crawler "$service" bash -c "bash experiment-stop.sh && bash experiment-join.sh '$ts' '$db'" 2>&1 \
    | grep -v 'already exists' || true
}

set_viewer_env() { # $1=db_name
  local env_file="$VIEWER_DIR/.env"
  if [ ! -f "$env_file" ]; then
    log "request-viewer/.env belum ada — isi DB_PASSWORD dari crawler/secrets/db_password.txt"
    {
      echo "DB_HOST=127.0.0.1"
      echo "DB_PORT=55434"
      echo "DB_USER=postgres"
      echo "DB_PASSWORD=\"$(tr -d '\n' < crawler/secrets/db_password.txt)\""
    } > "$env_file"
  fi
  if grep -q '^DB_NAME=' "$env_file"; then
    sed -i '' "s/^DB_NAME=.*/DB_NAME=\"$1\"/" "$env_file"
  else
    echo "DB_NAME=\"$1\"" >> "$env_file"
  fi
  log "request-viewer/.env -> DB_NAME=$1 (restart 'npm run dev' kalau sedang jalan)"
}

join_all() { # $1=db_name
  local db=$1
  for w in $WORKERS; do join_worker "$w" "$db"; done
  set_viewer_env "$db"
  log "Selesai. Eksperimen aktif: $db"
}

cmd_new() {
  up
  local ts db
  ts=$(date '+%Y_%m_%d_%H_%M_%S')
  db="userdiff_manual___$ts"
  log "Membuat eksperimen baru: $db"
  join_all "$db"
}

cmd_join() {
  up
  local db=${1:-$(latest_experiment)}
  [ -n "$db" ] || die "Belum ada eksperimen. Jalankan: ./vsf.sh new"
  join_all "$db"
}

cmd_work() {
  log "Memulai kunjungan manual di userdiff_worker1 (browser muncul di VNC localhost:55905). Ctrl+C untuk berhenti."
  dc exec -w /crawler userdiff_worker1 bash -c '[ -f manual-work.sh ] || { echo "Worker belum join eksperimen. Jalankan ./vsf.sh join dulu."; exit 1; }; bash manual-work.sh "$@"' _ "$@"
}

cmd_viewer() {
  cd "$VIEWER_DIR"
  [ -d node_modules ] || npm install
  npm run dev
}

cmd_status() {
  dc ps --format 'table {{.Service}}\t{{.Status}}'
  echo
  log "Eksperimen:"
  psql_db "select datname from pg_database where datname like 'userdiff_manual___%' order by 1" | sed 's/^/  /'
  local db; db=$(latest_experiment)
  if [ -n "$db" ]; then
    echo
    log "Isi tabel ($db):"
    for t in subjects sessions visit_tasks analysis_candidate_pairs swap_tasks swap_candidate_pairs swap_request; do
      printf '  %-26s %s\n' "$t" "$(dc exec -T crawler-db psql -U postgres -d "$db" -Atc "select count(*) from $t" 2>/dev/null || echo '-')"
    done
  fi
}

cmd_stop() {
  for w in $WORKERS; do
    log "Stop $w"
    dc exec -T -w /crawler "$w" bash experiment-stop.sh || true
  done
}

case "${1:-}" in
  new)    cmd_new ;;
  join)   shift; cmd_join "${1:-}" ;;
  work)   shift; cmd_work "$@" ;;
  viewer) cmd_viewer ;;
  status) cmd_status ;;
  stop)   cmd_stop ;;
  *)      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
