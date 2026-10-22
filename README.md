# 🧠 Duygu Asistanı - NLP Tabanlı Duygu Analizi ve Kişiselleştirilmiş Öneri Sistemi

Bu proje; kullanıcıların yazdığı Türkçe serbest metinleri Doğal Dil İşleme (NLP) yöntemleriyle analiz ederek duygu durumunu tespit eden ve sonuca göre kişiselleştirilmiş müzik, kitap ve aktivite önerileri sunan uçtan uca bir uygulamadır.

---

## 📸 Ekran Görüntüleri

### 1. Ana Giriş & Analiz Ekranı
Kullanıcının hislerini serbest metin olarak girdiği veya anlık duygu seçimi yapabildiği arayüz:

<img width="1253" height="709" alt="giris" src="https://github.com/user-attachments/assets/493884a7-9532-4fde-a04e-80cee31771cf" />

---

### 2. Dinamik Sonuç & Kişiselleştirilmiş Öneri Ekranları
Modelin tespit ettiği duygu durumuna göre arayüz teması, motive edici mesajlar ve öneri kartları (Müzik Terapisi, Zihin Besini, Günün Tarifi) dinamik olarak güncellenir:

<img width="1258" height="703" alt="mutlu" src="https://github.com/user-attachments/assets/ae87c657-fb0a-4f4c-87b2-2b9e1c76e9b6" />

<img width="1256" height="698" alt="uzgun" src="https://github.com/user-attachments/assets/ce1e617e-24fb-47a3-bbbe-34df57a7b784" />

---

## 🚀 Mimari ve Çalışma Mantığı

Uygulama, modern **İstemci-Sunucu (Client-Server)** mimarisi üzerine kurulmuştur:
1. **İstemci Katmanı (Flutter):** Kullanıcıdan alınan metinsel girdiler HTTP protokolü (POST isteği) üzerinden JSON formatında backend servisine iletilir.
2. **Yapay Zekâ & Analiz Katmanı (Python & BERTurk):** API sunucusu, gelen metni BERTurk ön eğitimli transformatör modeli üzerinden geçirerek duygu sınıflandırmasını gerçekleştirir.
3. **Dinamik İçerik & API Servisi:** Sınıflandırılan duygu kategorisine uygun öneri listesi (Spotify çalma listeleri, kitap önerileri vb.) JSON yanıtı olarak mobil arayüze döner ve ekran dinamik tema ile yeniden render edilir.

---

## 🛠️ Kullanılan Teknolojiler

- **Mobil / Arayüz:** Flutter, Dart (State Management, Dynamic Theming, HTTP Client)
- **Backend & API Servisi:** Python, RESTful API
- **Doğal Dil İşleme & ML:** BERTurk, PyTorch / Hugging Face Transformers
- **Protokoller & Veri:** HTTP (GET / POST), JSON
- **Versiyon Kontrol:** Git, GitHub

---
