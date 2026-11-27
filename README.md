# AutoLine Tycoon

Game simulasi manajemen lini produksi (*Idle / Tycoon*) untuk Android yang dibangun dengan **Flutter**.

## Fitur Utama
- **4 Stasiun Produksi Berurutan:** Stamping Press, Robotic Welding, Final Assembly, dan Quality Check (QC).
- **Simulasi Bottleneck & WIP Buffer:** Tiap stasiun mengirim unit ke buffer stasiun berikutnya—pemain harus menyeimbangkan kecepatan lini agar output tidak tertahan.
- **Tap-to-Boost & Turbo Mode:** Ketuk stasiun untuk mempercepat siklus secara manual atau aktifkan *2x Overdrive Turbo* selama 30 detik.
- **Upgrade Speed, Batch & R&D Product Tier:** Tingkatkan kecepatan mesin, kapasitas batch, serta nilai jual unit dari *Compact Car* hingga *Cyber Mecha*.
- **Auto-Save & Offline Earnings:** Progres tersimpan otomatis secara lokal dan tetap menghasilkan pendapatan saat aplikasi ditutup (maksimal 8 jam).

## Build APK Otomatis (GitHub Actions)
Setiap push ke branch `main` (atau manual lewat tab **Actions**) akan otomatis:
1. Men-generate scaffold Android dengan Flutter Stable.
2. Menjalankan `flutter analyze` & `flutter build apk --release`.
3. Mengunggah file `.apk` ke **Artifacts** sekaligus merilisnya di halaman **GitHub Releases**.
