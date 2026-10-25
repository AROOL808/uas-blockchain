# 🎓 DiplomaRegistry Web3 Portal

DiplomaRegistry adalah aplikasi terdesentralisasi (dApp) untuk menerbitkan, mencabut (revoke), dan memverifikasi keaslian dokumen ijazah menggunakan teknologi *blockchain*. Aplikasi ini dibangun menggunakan arsitektur relayer, di mana pengguna (Client) berinteraksi dengan antarmuka web, sementara *backend* (Express.js) menangani tanda tangan transaksi dan pembayaran *gas fee* ke jaringan ARC Testnet.

## 🌟 Fitur Utama
*   **Keamanan Terdesentralisasi:** Penyimpanan *hash* dokumen secara *on-chain* melalui *smart contract* `DiplomaRegistry.sol`.
*   **Privasi Maksimal (Zero-Knowledge Concept):** File PDF dan nomor ID tidak pernah diunggah ke *server* atau *blockchain*. Proses *hashing* (SHA-256 untuk file dan Keccak-256 untuk teks) dilakukan 100% secara lokal di *browser* klien.
*   **Penerbitan Ijazah (Issue):** Fitur untuk mendaftarkan *hash* ijazah ke dalam *blockchain* (membutuhkan validasi pembayaran *fee* token).
*   **Pencabutan Ijazah (Revoke):** Fitur untuk membatalkan status ijazah yang salah cetak atau tidak valid dengan mencatatkan alasan pencabutan secara permanen di *blockchain*.
*   **Verifikasi Publik (Verify):** Pengecekan instan, gratis, dan tanpa perlu dompet kripto untuk memvalidasi apakah file PDF yang dipegang pengguna cocok dengan data *on-chain*.

---

## 🛠️ Arsitektur & Teknologi

*   **Smart Contract:** Solidity (Hardhat)
*   **Jaringan Blockchain:** ARC Testnet
*   **Backend / Relayer:** Node.js & Express.js
*   **Web3 Library:** Ethers.js v6 (Frontend & Backend)
*   **Frontend UI:** HTML5, Vanilla JavaScript, Tailwind CSS (via CDN)

---

## 📦 Dependensi

Pastikan lingkungan lokal Anda telah memenuhi persyaratan berikut sebelum melakukan instalasi:
1.  **Node.js** (Minimal v16.x, disarankan v18.x LTS)
2.  **NPM** (Node Package Manager)

Modul Node.js utama yang digunakan (lihat `package.json`):
*   `express` - Framework server backend.
*   `ethers` - Pustaka untuk interaksi *blockchain* dan manipulasi kriptografi.
*   `dotenv` - Pengelolaan variabel lingkungan yang aman.

---

## ⚙️ Konfigurasi Lingkungan (.env)

Buat file `.env` di *root* folder proyek Anda dan isi dengan variabel berikut:

```env
# Konfigurasi Server
PORT=3000

# Konfigurasi Jaringan & Kontrak (ARC Testnet)
ARC_TESTNET_RPC_URL=[https://rpc.testnet.arc.io](https://rpc.testnet.arc.io)
CONTRACT_ADDRESS=0x00A4664621a9530c4C86eE4D92A699d6649Df0E7

# Kredensial Backend Relayer 
# Ini adalah Private Key dompet yang akan membayar Gas Fee untuk transaksi blockchain.
# Dompet ini HARUS didaftarkan sebagai ISSUER oleh Admin di Smart Contract.
PRIVATE_KEY=[REDACTED]
# Konfigurasi Fee Penerbitan
# Nominal token (dalam satuan ether/native) yang wajib ditransfer Issuer ke Admin.
FEE_AMOUNT=0.1
# Alamat dompet Admin yang berhak menerima pembayaran Fee.
ADMIN_WALLET_ADDRESS=0xC49B26c2d7dd14896DfBc9A8927678E1F0182B68
```

## 🚀 Panduan Instalasi Lengkap

Ikuti langkah-langkah di bawah ini untuk menjalankan proyek DiplomaRegistry di komputer lokal Anda.

### Tahap 1: Prasyarat Sistem
Pastikan komputer Anda sudah terinstal perangkat lunak berikut:
1. **Node.js**: Versi 16.x atau yang lebih baru (Disarankan v18 LTS). Cek dengan menjalankan `node -v` di terminal.
2. **NPM**: Biasanya sudah satu paket dengan Node.js. Cek dengan `npm -v`.
3. **Git**: Untuk mengkloning repositori (opsional jika Anda mengunduh ZIP).

### Tahap 2: Persiapan Folder Proyek
1. Buka terminal (Command Prompt / PowerShell / Terminal Mac-Linux).
2. Kloning repositori proyek ini:
   ```bash
   git clone <URL_REPOSITORI_ANDA>
   ```
3. Masuk ke dalam direktori proyek:
   ```bash
   cd DIPLOMA-REGISTRY
   ```

### Tahap 3: Instalasi Dependensi Server
Jalankan perintah berikut di dalam folder proyek untuk mengunduh semua pustaka yang dibutuhkan oleh Express.js dan Ethers.js:
```bash
npm install
```
*(Atau jika Anda belum membuat `package.json`, jalankan: `npm install express ethers dotenv`)*

### Tahap 4: Konfigurasi Smart Contract (ABI)
Agar *backend* Express.js bisa berinteraksi dengan *smart contract* di blockchain:
1. Masuk ke folder proyek Hardhat Anda (jika terpisah).
2. Cari file hasil kompilasi kontrak bernama `DiplomaRegistry.json` (biasanya berada di folder `artifacts/contracts/DiplomaRegistry.sol/`).
3. Buka file tersebut, salin seluruh isi *array* di dalam properti `"abi": [...]`.
4. Buat file baru bernama `abi.json` di *root* folder proyek Express Anda (sejajar dengan `server.js`).
5. Tempel (paste) *array* ABI tersebut ke dalam file `abi.json` dan simpan.

### Tahap 5: Konfigurasi Environment Variables (.env)
1. Buat file baru bernama `.env` di *root* folder proyek (sejajar dengan `server.js`).
2. Buka file `.env` dan masukkan konfigurasi berikut (sesuaikan isinya dengan data Anda):

```env
# Konfigurasi Server
PORT=3000

# Konfigurasi Jaringan & Kontrak (ARC Testnet)
ARC_TESTNET_RPC_URL=[https://rpc.testnet.arc.io](https://rpc.testnet.arc.io)
CONTRACT_ADDRESS=0x00A4664621a9530c4C86eE4D92A699d6649Df0E7

# Kredensial Backend Relayer 
# Ini adalah Private Key dompet yang akan membayar Gas Fee untuk transaksi blockchain.
# Dompet ini HARUS didaftarkan sebagai ISSUER oleh Admin di Smart Contract.
PRIVATE_KEY=[REDACTED]
# Konfigurasi Fee Penerbitan
# Nominal token (dalam satuan ether/native) yang wajib ditransfer Issuer ke Admin.
FEE_AMOUNT=0.1
# Alamat dompet Admin yang berhak menerima pembayaran Fee.
ADMIN_WALLET_ADDRESS=0xC49B26c2d7dd14896DfBc9A8927678E1F0182B68
```

### Tahap 6: Menjalankan Aplikasi
1. Pastikan Anda masih berada di dalam direktori proyek pada terminal.
2. Jalankan server backend menggunakan Node:
   ```bash
   node server.js
   ```
3. Jika konfigurasi benar, terminal akan menampilkan:
   `Server berjalan di http://localhost:3000`
4. Buka *browser* web Anda (Chrome, Firefox, Safari) dan akses URL: **http://localhost:3000**

Aplikasi Web3 Registrasi Ijazah Anda kini siap digunakan!