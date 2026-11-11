# VSF Helper (`vsf.sh`)

Skrip bantu untuk menjalankan alur VSF dari Terminal host (Mac), tanpa perlu masuk
ke dalam container satu per satu. Jalankan dari dalam folder `framework/`.

```bash
cd framework
./vsf.sh <perintah>
```

## Daftar Perintah

| Perintah | Keterangan |
|---|---|
| `./vsf.sh new` | Menyalakan container, **membuat eksperimen baru** (`userdiff_manual___<tanggal>`), menyambungkan ketiga worker ke eksperimen itu, lalu mengisi `DB_NAME` di `request-viewer/.env` secara otomatis. |
| `./vsf.sh join [ID]` | Menyambungkan ketiga worker ke eksperimen **yang sudah ada**. Jika `ID` tidak diisi, dipakai eksperimen **terbaru**. Pakai ini tiap kali Docker atau laptop di-restart. |
| `./vsf.sh work` | Memulai sesi **kunjungan manual** di `userdiff_worker1` (mode delayed swapping). Browser muncul lewat VNC di `localhost:55905`. |
| `./vsf.sh work --live` | Sama seperti `work`, tapi mode **live swapping** (swap dikirim langsung saat kunjungan). |
| `./vsf.sh viewer` | Menjalankan **request-viewer** di http://localhost:3000. Menjalankan `npm install` otomatis jika `node_modules` belum ada. |
| `./vsf.sh status` | Menampilkan status container, daftar eksperimen, dan jumlah baris di tabel-tabel utama. |
| `./vsf.sh stop` | Menghentikan proses eksperimen (analysis worker, zmq listener, swap crawler) di semua worker. |

## Alur Pemakaian Normal

```bash
cd framework

# Pertama kali / mulai eksperimen baru:
./vsf.sh new

# Setelah restart Docker atau laptop (join ke eksperimen yang sudah ada):
./vsf.sh join

# Terminal 1 — kunjungi situs target lewat VNC (localhost:55905):
./vsf.sh work

# Terminal 2 — lihat hasil swap:
./vsf.sh viewer        # buka http://localhost:3000

# Cek apakah data sudah masuk:
./vsf.sh status
```

## Catatan

- **Mapping worker → container:**
  - `userdiff_auto`  → filter & analisis otomatis + ZMQ listener (ambil pasangan sesi)
  - `userdiff_worker1` → kunjungan manual (yang Anda jalankan dengan `work`)
  - `swap_auto` → crawler swapping otomatis
- **ID eksperimen** berbentuk `userdiff_manual___YYYY_MM_DD_HH_MM_SS`. Simpan ID yang
  sedang aktif; `./vsf.sh status` selalu menampilkannya.
- **`request-viewer/.env`:** `DB_NAME` diisi/di-update otomatis oleh `new` dan `join`.
  Jika `npm run dev` sedang berjalan, **restart** supaya nilai baru terbaca.
- **Error `relation "swap_tasks" does not exist`** di viewer = `DB_NAME` menunjuk ke
  database yang salah (mis. `postgres`). Jalankan `./vsf.sh join` untuk memperbaikinya.
- **Semua tabel masih 0?** Task baru muncul setelah Account Framework (`accf-auto`,
  dihubungi lewat ZMQ) menyediakan pasangan akun. Tanpa itu, worker tidak mendapat task.
- Perintah interaktif asli (`experiment-list.sh` yang pakai menu `dialog`) diganti
  skrip ini dengan pemanggilan langsung `experiment-join.sh`, jadi bisa dijalankan
  non-interaktif dari host.
