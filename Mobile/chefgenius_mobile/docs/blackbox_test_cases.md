# Blackbox Test Case Document
## Aplikasi ChefGenius Mobile

| Versi | Tanggal | Tester |
|-------|---------|--------|
| 1.0 | 2024-12-20 | [Nama Tester] |

---

## 1. Modul Authentication

### TC-AUTH-001: Login dengan Email Valid
| Item | Detail |
|------|--------|
| **Precondition** | User sudah terdaftar, app terinstall |
| **Test Steps** | 1. Buka app<br>2. Masukkan email valid<br>3. Masukkan password valid<br>4. Klik tombol Login |
| **Expected Result** | User berhasil masuk ke halaman utama (Pantry) |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-AUTH-002: Login dengan Password Salah
| Item | Detail |
|------|--------|
| **Precondition** | User sudah terdaftar |
| **Test Steps** | 1. Masukkan email valid<br>2. Masukkan password salah<br>3. Klik Login |
| **Expected Result** | Muncul pesan error "Password salah" |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-AUTH-003: Register User Baru
| Item | Detail |
|------|--------|
| **Precondition** | Email belum terdaftar |
| **Test Steps** | 1. Klik "Daftar"<br>2. Isi email, password, nama<br>3. Klik Register |
| **Expected Result** | User terdaftar, masuk ke halaman intro |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-AUTH-004: Logout
| Item | Detail |
|------|--------|
| **Precondition** | User sudah login |
| **Test Steps** | 1. Buka Profile<br>2. Klik menu<br>3. Pilih Logout<br>4. Konfirmasi |
| **Expected Result** | User keluar, kembali ke Login screen |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

---

## 2. Modul Recipe Generation (AI)

### TC-AI-001: Generate Resep dengan Prompt Valid
| Item | Detail |
|------|--------|
| **Precondition** | User login, online |
| **Test Steps** | 1. Buka tab Chef AI<br>2. Ketik "Ayam goreng crispy"<br>3. Pilih persona<br>4. Klik Buat Resep |
| **Expected Result** | Muncul resep dengan judul, bahan, langkah |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-AI-002: Generate Resep saat Offline
| Item | Detail |
|------|--------|
| **Precondition** | User dalam mode offline |
| **Test Steps** | 1. Matikan internet<br>2. Buka Chef AI<br>3. Coba generate resep |
| **Expected Result** | Muncul pesan "Offline" dan tombol disabled |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-AI-003: Generate Multiple Resep
| Item | Detail |
|------|--------|
| **Precondition** | User level 5+, online |
| **Test Steps** | 1. Pilih jumlah resep = 3<br>2. Generate |
| **Expected Result** | Muncul 3 resep berbeda |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

---

## 3. Modul Community

### TC-COM-001: Upload Postingan dengan Foto
| Item | Detail |
|------|--------|
| **Precondition** | User login |
| **Test Steps** | 1. Buka Social<br>2. Klik tombol +<br>3. Pilih foto<br>4. Isi caption<br>5. Pilih kategori<br>6. Klik kirim |
| **Expected Result** | Postingan berhasil diupload, muncul di feed |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-COM-002: Like Postingan
| Item | Detail |
|------|--------|
| **Precondition** | Ada postingan di feed |
| **Test Steps** | 1. Klik icon hati pada postingan |
| **Expected Result** | Icon berubah merah, like count +1, pemilik dapat notifikasi |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-COM-003: Unlike Postingan
| Item | Detail |
|------|--------|
| **Precondition** | User sudah like postingan |
| **Test Steps** | 1. Klik icon hati yang sudah merah |
| **Expected Result** | Icon kembali outline, like count -1 |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-COM-004: Tambah Komentar
| Item | Detail |
|------|--------|
| **Precondition** | Ada postingan |
| **Test Steps** | 1. Klik icon komentar<br>2. Ketik komentar<br>3. Kirim |
| **Expected Result** | Komentar muncul, pemilik post dapat notifikasi |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-COM-005: Reply Komentar
| Item | Detail |
|------|--------|
| **Precondition** | Ada komentar di postingan |
| **Test Steps** | 1. Klik "Balas" di komentar<br>2. Ketik balasan<br>3. Kirim |
| **Expected Result** | Reply muncul, user yang direply dapat notifikasi |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-COM-006: Share Postingan
| Item | Detail |
|------|--------|
| **Precondition** | Ada postingan |
| **Test Steps** | 1. Klik icon share<br>2. Pilih platform (WA/Copy Link) |
| **Expected Result** | Link dibagikan, share count +1, pemilik dapat notifikasi |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-COM-007: Save Postingan
| Item | Detail |
|------|--------|
| **Precondition** | Ada postingan |
| **Test Steps** | 1. Klik icon bookmark |
| **Expected Result** | Postingan tersimpan, bisa dilihat di Saved Posts |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

---

## 4. Modul Notifications

### TC-NOTIF-001: Badge Muncul saat Ada Notifikasi Baru
| Item | Detail |
|------|--------|
| **Precondition** | Ada notifikasi unread |
| **Test Steps** | 1. Buka tab Social |
| **Expected Result** | Badge merah dengan angka muncul di icon notifikasi |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-NOTIF-002: Buka Halaman Notifikasi
| Item | Detail |
|------|--------|
| **Precondition** | Ada notifikasi |
| **Test Steps** | 1. Klik icon notifikasi |
| **Expected Result** | Daftar notifikasi muncul dengan jenis aktivitas |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-NOTIF-003: Klik Notifikasi Navigasi ke Post
| Item | Detail |
|------|--------|
| **Precondition** | Ada notifikasi like/komentar |
| **Test Steps** | 1. Klik notifikasi |
| **Expected Result** | Navigasi ke postingan terkait |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

---

## 5. Modul Profile

### TC-PROF-001: Lihat Profile Sendiri
| Item | Detail |
|------|--------|
| **Precondition** | User login |
| **Test Steps** | 1. Klik tab Profile |
| **Expected Result** | Muncul foto, nama, bio, postingan user |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-PROF-002: Edit Profile
| Item | Detail |
|------|--------|
| **Precondition** | Di halaman profile sendiri |
| **Test Steps** | 1. Klik Edit Profile<br>2. Ubah nama/bio<br>3. Simpan |
| **Expected Result** | Data profile terupdate |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-PROF-003: Lihat Profile Orang Lain
| Item | Detail |
|------|--------|
| **Precondition** | Ada postingan orang lain |
| **Test Steps** | 1. Klik avatar/nama di postingan |
| **Expected Result** | Navigasi ke profile orang tersebut |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

---

## 6. Modul Pantry

### TC-PAN-001: Tambah Bahan ke Pantry
| Item | Detail |
|------|--------|
| **Precondition** | Di halaman Pantry |
| **Test Steps** | 1. Ketik nama bahan<br>2. Tekan enter/tambah |
| **Expected Result** | Bahan muncul di daftar pantry |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-PAN-002: Cari Resep dari Bahan Pantry
| Item | Detail |
|------|--------|
| **Precondition** | Ada bahan di pantry |
| **Test Steps** | 1. Klik "Cari Resep dari Buku Resep" |
| **Expected Result** | Muncul resep yang mengandung bahan tersebut |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

### TC-PAN-003: Hapus Bahan dari Pantry
| Item | Detail |
|------|--------|
| **Precondition** | Ada bahan di pantry |
| **Test Steps** | 1. Swipe/klik hapus pada bahan |
| **Expected Result** | Bahan dihapus dari daftar |
| **Actual Result** | |
| **Status** | ⬜ Pass / ⬜ Fail |

---

## Summary

| Modul | Total TC | Pass | Fail |
|-------|----------|------|------|
| Authentication | 4 | | |
| Recipe AI | 3 | | |
| Community | 7 | | |
| Notifications | 3 | | |
| Profile | 3 | | |
| Pantry | 3 | | |
| **TOTAL** | **23** | | |
