import csv
import datetime
import os
import random
from typing import Dict, List

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
import torch
from transformers import BertForSequenceClassification, BertTokenizer
import uvicorn

# =============================================================
# 🚀 1. SİSTEM AYARLARI VE BAŞLATMA
# =============================================================

load_dotenv()

app = FastAPI(title="Duygu Asistanı API", version="8.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class UserRequest(BaseModel):
  text: str


class FeedbackRequest(BaseModel):
  text: str
  mood: str
  vote: str


LOG_FILE = "kullanici_oylari.csv"
if not os.path.exists(LOG_FILE):
  with open(LOG_FILE, mode="w", newline="", encoding="utf-8") as f:
    csv.writer(f).writerow(
        ["Tarih", "Kullanici_Metni", "Tahmin_Edilen_Mod", "Kullanici_Oyu"]
    )

MODEL_PATH = "./model_files"
TOKENIZER_PATH = "./tokenizer_files"

CLIENT_ID = os.getenv("SPOTIFY_CLIENT_ID")
CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET")

sp = spotipy.Spotify(
    auth_manager=SpotifyClientCredentials(
        client_id=CLIENT_ID, client_secret=CLIENT_SECRET
    )
)

try:
    sp = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
        client_id=CLIENT_ID, client_secret=CLIENT_SECRET))
    print("✅ Spotify bağlantısı kuruldu.")
except Exception as e:
    sp = None
    print(f"⚠️ Spotify hatası: {e}")

print("🔄 Model yükleniyor...")
device    = torch.device("cuda" if torch.cuda.is_available() else "cpu")
tokenizer = BertTokenizer.from_pretrained(TOKENIZER_PATH)
model     = BertForSequenceClassification.from_pretrained(MODEL_PATH)
model.to(device)
model.eval()
print(f"✅ Hazır! ({device})")

id2label = {0: 'Anger', 1: 'Disgust', 2: 'Fear', 3: 'Happy', 4: 'Sadness', 5: 'Surprise'}

# =============================================================
# 🧠 2. ANALİZ MOTORU
# =============================================================
def get_mood_analysis(text: str):
    text_lower = text.lower()
    inputs = tokenizer(text, return_tensors="pt", truncation=True,
                       padding=True, max_length=128).to(device)
    with torch.no_grad():
        probs      = torch.nn.functional.softmax(model(**inputs).logits, dim=1).cpu().numpy()[0]
        pred_idx   = int(probs.argmax())
        bert_label = id2label[pred_idx]
        confidence = float(probs[pred_idx])

    stressed_kw = ["stresli","stress","gergin","gerginim","gerilim","baskı",
                   "bunalıyorum","bunaltıcı","yoğun iş","yetiştiremiyorum",
                   "deadline","sıkıştım","tükendim","dinlenemiyorum",
                   "rahat edemiyorum","omuzlarım ağır"]
    tired_kw    = ["yorgun","bitkin","uyku","halsiz","pestil"]
    fear_kw     = ["sunum","titriyor","korkuyorum","panik"]
    negation_kw = ["iyi değilim","keyfim yok","mutlu değilim",
                   "moralim bozuk","canım sıkkın"]
    happy_kw    = ["keşfetmek","tura çıkmak","harika","sevindim",
                   "bayıldım","keyifli","mutlu eder"]
    complex_kw  = ["hem","ama","fakat","ancak","yine de",
                   "garip hissediyorum","karışık","karışığım"]
    disgust_kw  = ["iğrenç","tiksiniyorum","tiksinti","mide bulandırıcı",
                   "rahatsız edici","berbat","nefret","dayanamıyorum",
                   "çirkin","iğrenme","kusma","midemi bulandırıyor"]

    if any(x in text_lower for x in complex_kw):   return "Complex",  0.90
    if any(x in text_lower for x in happy_kw):     return "Happy",    0.95
    if any(x in text_lower for x in disgust_kw):   return "Disgust",  0.92
    if any(x in text_lower for x in stressed_kw):  return "Stressed", 0.92
    if any(x in text_lower for x in tired_kw):     return "Stressed", confidence
    if any(x in text_lower for x in fear_kw):      return "Fear",     confidence
    if any(x in text_lower for x in negation_kw):  return "Sadness",  confidence
    if confidence < 0.35:                           return "Complex",  confidence
    return bert_label, confidence


# =============================================================
# 🎵 3. MÜZİK ÖNERİ MOTORU —  (Spotify API)
# =============================================================
SPOTIFY_QUERIES: Dict[str, List[str]] = {
    "Happy": [
        "türkçe dans pop neşeli",
        "Tarkan Kenan Doğulu Edis oynak",
        "türkçe summer pop upbeat",
        "feel good pop dance",
        "funk soul happy upbeat",
        "turkish pop party hits",
        "Gülşen Sertab Erener enerjik",
    ],
    "Sadness": [
        "türkçe hüzünlü şarkı",
        "Duman Pinhani Canozan melankoli",
        "türkçe akustik duygusal",
        "Sezen Aksu hüzün balad",
        "sad indie acoustic guitar",
        "melancholic piano vocal",
        "türkçe yavaş balad",
    ],
    "Anger": [
        "türkçe rock sert güçlü",
        "Mor ve Ötesi maNga Hayko rock",
        "hard rock metal powerful",
        "türkçe alternatif rock",
        "rage alternative metal",
        "Athena Duman sert rock",
        "punk rock energy",
    ],
    "Complex": [
        "türkçe alternatif indie düşündürücü",
        "Mabel Matiz Büyük Ev Ablukada",
        "Dolu Kadehi Ters Tut",
        "indie folk introspective deep",
        "türkçe post rock ambient",
        "art rock progressive thoughtful",
        "Teoman Kıraç derin",
    ],
    "Stressed": [
        "türkçe akustik sakin dinlendirici",
        "Bülent Ortaçgil Yeni Türkü huzur",
        "lofi chill relax study",
        "ambient stress relief calm",
        "türkçe halk müziği sakin",
        "Evrencan Gündüz dinlendirici",
        "acoustic soft calm peaceful",
    ],
    "Fear": [
        "Ludovico Einaudi peaceful piano",
        "classical calming anxiety relief",
        "ambient peaceful nature sounds",
        "türkçe sakin enstrümantal",
        "meditation relaxation healing",
        "Evgeny Grinko calm piano",
        "soft instrumental peaceful",
    ],
    "Surprise": [
        "türkçe enerjik pop canlı",
        "upbeat energetic pop dance",
        "türkçe elektronik dance",
        "fun quirky upbeat music",
        "Sertab Erener KÖFN enerjik",
        "pop dance surprise hits",
        "türkçe elektropop",
    ],
    "Disgust": [
        "türkçe huzurlu akustik şarkılar",
        "türkçe sakin indie pop",
        "türkçe ferahlatıcı müzikler",
        "relaxing acoustic guitar music",
        "peaceful piano instrumental",
        "calm morning acoustic playlist",
        "Nova Norda sakin şarkılar",
        "Kalben huzurlu şarkılar",
        "Can Ozan akustik parçalar",
        "Pinhani sakin şarkılar",
    ],
}

VETO = ["remix", "live", "canlı", "karaoke", "instrumental",
        "enstrümantal", "ninni", "edit"]

def get_spotify_list(mood: str) -> List[Dict]:
    if not sp:
        return []
    queries = SPOTIFY_QUERIES.get(mood, ["türkçe pop"])[:]
    random.shuffle(queries)
    seen: Dict[str, dict] = {}
    for query in queries:
        if len(seen) >= 12:
            break
        try:
            res = sp.search(q=query, type="track", limit=15, market="TR")
            for t in res['tracks']['items']:
                url  = t['external_urls']['spotify']
                name = t['name']
                if url in seen or any(v in name.lower() for v in VETO):
                    continue
                seen[url] = {
                    "name":   name,
                    "artist": t['artists'][0]['name'],
                    "url":    url,
                    "image":  t['album']['images'][0]['url'] if t['album']['images'] else "",
                }
        except Exception as e:
            print(f"Spotify sorgu hatası ({query}): {e}")
            continue
    pool = list(seen.values())
    random.shuffle(pool)
    return pool[:4]


# =============================================================
# 📚 4. KİTAP ÖNERİ MOTORU — 
# =============================================================

BOOK_QUERIES: Dict[str, List[str]] = {
    "Happy": [
        "mutluluk roman neşe",
        "happiness novel joy fiction",
        "komedi hikaye eğlenceli",
        "feel good positive novel",
        "neşeli psikoloji kitap",
    ],
    "Sadness": [
        "dram roman hüzün aşk",
        "melancholy sad drama fiction",
        "hüzünlü edebiyat roman",
        "emotional literary fiction grief",
        "klasik roman üzüntü",
    ],
    "Anger": [
        "öfke psikoloji kitap",
        "stoicism anger philosophy",
        "stoacılık marcus aurelius",
        "anger management self help",
        "motivasyon güç liderlik",
    ],
    "Complex": [
        "varoluşçuluk felsefe roman",
        "existentialism philosophy novel",
        "psikoloji bilinç derin roman",
        "absurd fiction kafka camus",
        "derin felsefi edebiyat",
    ],
    "Stressed": [
        "meditasyon sakinlik kitap",
        "mindfulness stress relief",
        "huzur nefes psikoloji",
        "anxiety calm self help book",
        "rahatlama doğa felsefe",
    ],
    "Fear": [
        "polisiye gerilim roman",
        "thriller mystery detective novel",
        "cesaret özgüven kitap",
        "courage fear overcome book",
        "macera roman",
    ],
    "Disgust": [
        "doğa seyahat edebiyat",
        "nature travel inspiration book",
        "pozitif düşünce yeni başlangıç",
        "positive thinking fresh start novel",
        "ilham verici hikaye",
    ],
    "Surprise": [
        "macera keşif roman",
        "adventure discovery fiction",
        "bilim kurgu sürpriz",
        "science fiction surprise novel",
        "biyografi ilham verici",
    ],
}

OPENLIBRARY_QUERIES: Dict[str, str] = {
    "Happy":   "happiness joy positive novel",
    "Sadness": "melancholy drama sadness grief",
    "Anger":   "stoicism anger philosophy",
    "Complex": "existentialism philosophy kafka camus",
    "Stressed":"mindfulness meditation calm anxiety",
    "Fear":    "thriller mystery detective",
    "Disgust": "nature travel inspiration healing",
    "Surprise":"adventure discovery science fiction",
}

def _google_books(sorgu: str, max_results: int = 8) -> List[Dict]:
    """
    Google Books API.
    ⚠️ langRestrict KALDIRILDI — TR kısıtlaması sonuçları sıfırlıyordu.
    Hem Türkçe hem İngilizce kitaplar gelir, bu normaldir.
    """
    try:
        url  = (
            f"https://www.googleapis.com/books/v1/volumes"
            f"?q={requests.utils.quote(sorgu)}"
            f"&maxResults={max_results}"
            f"&orderBy=relevance"
            f"&printType=books"
        )
        resp = requests.get(url, timeout=5).json()
        books = []
        if "items" in resp:
            for item in resp["items"]:
                v    = item.get("volumeInfo", {})
                link = v.get("infoLink", "")
                if not link:
                    continue
                img = (v.get("imageLinks", {})
                         .get("thumbnail", "")
                         .replace("http://", "https://"))
                books.append({
                    "title":  v.get("title", "Kitap"),
                    "author": ", ".join(v.get("authors", ["Bilinmeyen"])),
                    "image":  img or "https://via.placeholder.com/150x220",
                    "link":   link,
                })
        return books
    except Exception as e:
        print(f"Google Books hatası ({sorgu}): {e}")
        return []

def _openlibrary(sorgu: str) -> List[Dict]:
    """
    OpenLibrary fallback.
    ⚠️ language=tur kısıtlaması KALDIRILDI — Türkçe veri yetersizdi.
    """
    try:
        url  = (
            f"https://openlibrary.org/search.json"
            f"?q={requests.utils.quote(sorgu)}"
            f"&limit=10"
            f"&fields=title,author_name,cover_edition_key,key"
        )
        resp = requests.get(url, timeout=5).json()
        books = []
        for doc in resp.get("docs", []):
            title  = doc.get("title", "Kitap")
            author = ", ".join(doc.get("author_name", ["Bilinmeyen"])[:2])
            olid   = doc.get("cover_edition_key", "")
            img    = (f"https://covers.openlibrary.org/b/olid/{olid}-M.jpg"
                      if olid else "https://via.placeholder.com/150x220")
            key    = doc.get("key", "")
            link   = (f"https://openlibrary.org{key}"
                      if key else
                      f"https://openlibrary.org/search?q={requests.utils.quote(title)}")
            books.append({
                "title":  title,
                "author": author,
                "image":  img,
                "link":   link,
            })
        return books
    except Exception as e:
        print(f"OpenLibrary hatası ({sorgu}): {e}")
        return []


FALLBACK_BOOKS: Dict[str, List[Dict]] = {
    "Happy": [
        {"title": "Mutluluk Projesi",      "author": "Gretchen Rubin",  "image": "https://covers.openlibrary.org/b/isbn/9786054729111-M.jpg",  "link": "https://www.google.com.tr/search?q=Mutluluk+Projesi+Gretchen+Rubin+kitap"},
        {"title": "Şeker Portakalı",        "author": "Jose Mauro",      "image": "https://covers.openlibrary.org/b/isbn/9789750805837-M.jpg",  "link": "https://www.google.com.tr/search?q=Şeker+Portakalı+kitap"},
        {"title": "Simyacı",               "author": "Paulo Coelho",    "image": "https://covers.openlibrary.org/b/isbn/9789753427739-M.jpg",  "link": "https://www.google.com.tr/search?q=Simyacı+Paulo+Coelho+kitap"},
        {"title": "Uçurtma Avcısı",        "author": "Khaled Hosseini", "image": "https://covers.openlibrary.org/b/isbn/9789750725036-M.jpg",  "link": "https://www.google.com.tr/search?q=Uçurtma+Avcısı+kitap"},
        {"title": "Martı",                 "author": "Richard Bach",    "image": "https://covers.openlibrary.org/b/isbn/9789750718809-M.jpg",  "link": "https://www.google.com.tr/search?q=Martı+Richard+Bach+kitap"},
        {"title": "Beyaz Diş",             "author": "Jack London",     "image": "https://covers.openlibrary.org/b/isbn/9789750263651-M.jpg",  "link": "https://www.google.com.tr/search?q=Beyaz+Diş+Jack+London+kitap"},
    ],
    "Sadness": [
        {"title": "Kürk Mantolu Madonna",  "author": "Sabahattin Ali",  "image": "https://covers.openlibrary.org/b/isbn/9789750719387-M.jpg",  "link": "https://www.google.com.tr/search?q=Kürk+Mantolu+Madonna+kitap"},
        {"title": "Küçük Prens",           "author": "Antoine",         "image": "https://covers.openlibrary.org/b/isbn/9789750263668-M.jpg",  "link": "https://www.google.com.tr/search?q=Küçük+Prens+kitap"},
        {"title": "İnsan Ne İle Yaşar",    "author": "Lev Tolstoy",     "image": "https://covers.openlibrary.org/b/isbn/9789750718526-M.jpg",  "link": "https://www.google.com.tr/search?q=İnsan+Ne+İle+Yaşar+kitap"},
        {"title": "Aşk",                   "author": "Elif Şafak",      "image": "https://covers.openlibrary.org/b/isbn/9789750718342-M.jpg",  "link": "https://www.google.com.tr/search?q=Aşk+Elif+Şafak+kitap"},
        {"title": "Suç ve Ceza",           "author": "Dostoyevski",     "image": "https://covers.openlibrary.org/b/isbn/9789750718908-M.jpg",  "link": "https://www.google.com.tr/search?q=Suç+ve+Ceza+kitap"},
        {"title": "Gece Yarısı Kütüphanesi","author": "Matt Haig",      "image": "https://covers.openlibrary.org/b/isbn/9780525559474-M.jpg",  "link": "https://www.google.com.tr/search?q=Gece+Yarısı+Kütüphanesi+kitap"},
    ],
    "Anger": [
        {"title": "Kendime Düşünceler",    "author": "Marcus Aurelius", "image": "https://covers.openlibrary.org/b/isbn/9789750263415-M.jpg",  "link": "https://www.google.com.tr/search?q=Kendime+Düşünceler+Marcus+Aurelius"},
        {"title": "Savaş Sanatı",          "author": "Sun Tzu",         "image": "https://covers.openlibrary.org/b/isbn/9789750718489-M.jpg",  "link": "https://www.google.com.tr/search?q=Savaş+Sanatı+Sun+Tzu+kitap"},
        {"title": "Öfke",                  "author": "Thich Nhat Hanh", "image": "https://covers.openlibrary.org/b/isbn/9781573223454-M.jpg",  "link": "https://www.google.com.tr/search?q=Öfke+Thich+Nhat+Hanh+kitap"},
        {"title": "Hayvan Çiftliği",       "author": "George Orwell",   "image": "https://covers.openlibrary.org/b/isbn/9789750263521-M.jpg",  "link": "https://www.google.com.tr/search?q=Hayvan+Çiftliği+Orwell+kitap"},
        {"title": "Güç İstenci",           "author": "Nietzsche",       "image": "https://covers.openlibrary.org/b/isbn/9789750731020-M.jpg",  "link": "https://www.google.com.tr/search?q=Güç+İstenci+Nietzsche+kitap"},
        {"title": "İnce Memed",            "author": "Yaşar Kemal",     "image": "https://covers.openlibrary.org/b/isbn/9789750802294-M.jpg",  "link": "https://www.google.com.tr/search?q=İnce+Memed+Yaşar+Kemal+kitap"},
    ],
    "Complex": [
        {"title": "Tutunamayanlar",        "author": "Oğuz Atay",       "image": "https://covers.openlibrary.org/b/isbn/9789750718533-M.jpg",  "link": "https://www.google.com.tr/search?q=Tutunamayanlar+Oğuz+Atay+kitap"},
        {"title": "Yabancı",               "author": "Albert Camus",    "image": "https://covers.openlibrary.org/b/isbn/9789750263392-M.jpg",  "link": "https://www.google.com.tr/search?q=Yabancı+Camus+kitap"},
        {"title": "Bulantı",               "author": "Jean-Paul Sartre","image": "https://covers.openlibrary.org/b/isbn/9789750718830-M.jpg",  "link": "https://www.google.com.tr/search?q=Bulantı+Sartre+kitap"},
        {"title": "Siddharta",             "author": "Hermann Hesse",   "image": "https://covers.openlibrary.org/b/isbn/9789750718526-M.jpg",  "link": "https://www.google.com.tr/search?q=Siddharta+Hermann+Hesse+kitap"},
        {"title": "Sineklerin Tanrısı",    "author": "William Golding", "image": "https://covers.openlibrary.org/b/isbn/9789750263385-M.jpg",  "link": "https://www.google.com.tr/search?q=Sineklerin+Tanrısı+kitap"},
        {"title": "Kör",                   "author": "Jose Saramago",   "image": "https://covers.openlibrary.org/b/isbn/9789750718694-M.jpg",  "link": "https://www.google.com.tr/search?q=Kör+Saramago+kitap"},
    ],
    "Stressed": [
        {"title": "Huzur",                 "author": "Ahmet Hamdi",     "image": "https://covers.openlibrary.org/b/isbn/9789750719622-M.jpg",  "link": "https://www.google.com.tr/search?q=Huzur+Ahmet+Hamdi+kitap"},
        {"title": "Sakinlik",              "author": "Seneca",          "image": "https://covers.openlibrary.org/b/isbn/9789750731204-M.jpg",  "link": "https://www.google.com.tr/search?q=Sakinlik+Seneca+kitap"},
        {"title": "Şimdi Burada Ol",       "author": "Eckhart Tolle",   "image": "https://covers.openlibrary.org/b/isbn/9781577314806-M.jpg",  "link": "https://www.google.com.tr/search?q=Şimdi+Burada+Ol+Eckhart+Tolle+kitap"},
        {"title": "Aklını Başına Al",      "author": "Epiktetos",       "image": "https://covers.openlibrary.org/b/isbn/9789750731174-M.jpg",  "link": "https://www.google.com.tr/search?q=Aklını+Başına+Al+Epiktetos+kitap"},
        {"title": "Şimdi Bu Anı Yaşa",    "author": "Thich Nhat Hanh", "image": "https://covers.openlibrary.org/b/isbn/9781888375916-M.jpg",  "link": "https://www.google.com.tr/search?q=Şimdi+Bu+Anı+Yaşa+kitap"},
        {"title": "Olduğun Gibi Ol",       "author": "Osho",            "image": "https://covers.openlibrary.org/b/isbn/9789752891869-M.jpg",  "link": "https://www.google.com.tr/search?q=Olduğun+Gibi+Ol+Osho+kitap"},
    ],
    "Fear": [
        {"title": "Doğu Ekspresinde Cinayet","author":"Agatha Christie","image": "https://covers.openlibrary.org/b/isbn/9789750716720-M.jpg",  "link": "https://www.google.com.tr/search?q=Doğu+Ekspresinde+Cinayet+kitap"},
        {"title": "Cesaret",               "author": "Osho",            "image": "https://covers.openlibrary.org/b/isbn/9789752891852-M.jpg",  "link": "https://www.google.com.tr/search?q=Cesaret+Osho+kitap"},
        {"title": "Gece Yarısı Kütüphanesi","author":"Matt Haig",       "image": "https://covers.openlibrary.org/b/isbn/9780525559474-M.jpg",  "link": "https://www.google.com.tr/search?q=Gece+Yarısı+Kütüphanesi+kitap"},
        {"title": "Korku",                 "author": "Stefan Zweig",    "image": "https://covers.openlibrary.org/b/isbn/9789750718588-M.jpg",  "link": "https://www.google.com.tr/search?q=Korku+Stefan+Zweig+kitap"},
        {"title": "Sherlock Holmes",       "author": "Arthur Conan Doyle","image":"https://covers.openlibrary.org/b/isbn/9789750263460-M.jpg", "link": "https://www.google.com.tr/search?q=Sherlock+Holmes+kitap"},
        {"title": "Büyük Beklentiler",     "author": "Charles Dickens", "image": "https://covers.openlibrary.org/b/isbn/9789750718700-M.jpg",  "link": "https://www.google.com.tr/search?q=Büyük+Beklentiler+Dickens+kitap"},
    ],
    "Disgust": [
        {"title": "1984",                  "author": "George Orwell",   "image": "https://covers.openlibrary.org/b/isbn/9789750263521-M.jpg",  "link": "https://www.google.com.tr/search?q=1984+George+Orwell+kitap"},
        {"title": "Fahrenheit 451",        "author": "Ray Bradbury",    "image": "https://covers.openlibrary.org/b/isbn/9789750718625-M.jpg",  "link": "https://www.google.com.tr/search?q=Fahrenheit+451+kitap"},
        {"title": "Bülbülü Öldürmek",     "author": "Harper Lee",      "image": "https://covers.openlibrary.org/b/isbn/9780061935466-M.jpg",  "link": "https://www.google.com.tr/search?q=Bülbülü+Öldürmek+kitap"},
        {"title": "Küçük Prens",           "author": "Antoine",         "image": "https://covers.openlibrary.org/b/isbn/9789750263668-M.jpg",  "link": "https://www.google.com.tr/search?q=Küçük+Prens+kitap"},
        {"title": "Simyacı",               "author": "Paulo Coelho",    "image": "https://covers.openlibrary.org/b/isbn/9789753427739-M.jpg",  "link": "https://www.google.com.tr/search?q=Simyacı+Paulo+Coelho+kitap"},
        {"title": "Huzur",                 "author": "Ahmet Hamdi",     "image": "https://covers.openlibrary.org/b/isbn/9789750719622-M.jpg",  "link": "https://www.google.com.tr/search?q=Huzur+Ahmet+Hamdi+kitap"},
    ],
    "Surprise": [
        {"title": "Olağanüstü Bir Gece",   "author": "Stefan Zweig",    "image": "https://covers.openlibrary.org/b/isbn/9789750718588-M.jpg",  "link": "https://www.google.com.tr/search?q=Olağanüstü+Bir+Gece+Stefan+Zweig"},
        {"title": "Kara Kuğu",            "author": "Nassim Taleb",    "image": "https://covers.openlibrary.org/b/isbn/9780812973815-M.jpg",  "link": "https://www.google.com.tr/search?q=Kara+Kuğu+Nassim+Taleb+kitap"},
        {"title": "Yüzyıllık Yalnızlık",  "author": "Garcia Marquez",  "image": "https://covers.openlibrary.org/b/isbn/9789750718557-M.jpg",  "link": "https://www.google.com.tr/search?q=Yüzyıllık+Yalnızlık+kitap"},
        {"title": "Sıfır ile Bir Arasında","author": "Peter Thiel",     "image": "https://covers.openlibrary.org/b/isbn/9780804139021-M.jpg",  "link": "https://www.google.com.tr/search?q=Sıfır+ile+Bir+Arasında+kitap"},
        {"title": "Simyacı",               "author": "Paulo Coelho",    "image": "https://covers.openlibrary.org/b/isbn/9789753427739-M.jpg",  "link": "https://www.google.com.tr/search?q=Simyacı+Paulo+Coelho+kitap"},
        {"title": "Küçük Prens",           "author": "Antoine",         "image": "https://covers.openlibrary.org/b/isbn/9789750263668-M.jpg",  "link": "https://www.google.com.tr/search?q=Küçük+Prens+kitap"},
    ],
}

def get_book_list(mood: str) -> List[Dict]:
    """
    Kitap önerisi — 4 katmanlı, her zaman sonuç garantili strateji:
      1. Google Books (langRestrict olmadan) — 3 farklı sorgu
      2. OpenLibrary (dil kısıtlaması olmadan) — fallback
      3. Farklı sorgularla Google Books tekrar — 2. fallback
      4. FALLBACK_BOOKS sabit listesi — API tamamen çökseydi bile çalışır
    """
    queries = BOOK_QUERIES.get(mood, ["novel fiction"])[:]
    random.shuffle(queries)

    seen: Dict[str, dict] = {}   

    # ── Katman 1: Google Books, 3 sorgu ──────────────────────
    for sorgu in queries[:3]:
        if len(seen) >= 8:
            break
        for book in _google_books(sorgu, max_results=8):
            if book["link"] not in seen:
                seen[book["link"]] = book

    # ── Katman 2: Yeterli gelmezse OpenLibrary ────────────────
    if len(seen) < 4:
        ol_query = OPENLIBRARY_QUERIES.get(mood, "fiction novel")
        for book in _openlibrary(ol_query):
            if book["link"] not in seen and len(seen) < 8:
                seen[book["link"]] = book

    # ── Katman 3: Hâlâ yeterli yoksa kalan sorgularla tekrar ─
    if len(seen) < 4:
        for sorgu in queries[3:]:
            if len(seen) >= 6:
                break
            for book in _google_books(sorgu, max_results=6):
                if book["link"] not in seen:
                    seen[book["link"]] = book

    pool = list(seen.values())
    random.shuffle(pool)

    # ── Katman 4: API tamamen başarısız → sabit yedek liste ──
    # Bu katman hiçbir zaman boş dönmez.
    if len(pool) < 4:
        fallback = FALLBACK_BOOKS.get(mood, FALLBACK_BOOKS["Happy"])[:]
        random.shuffle(fallback)
        existing_titles = {b["title"] for b in pool}
        for b in fallback:
            if b["title"] not in existing_titles and len(pool) < 4:
                pool.append(b)
                existing_titles.add(b["title"])

    return pool[:4]


# =============================================================
# 🍔 5. YEMEK ÖNERİ MOTORU —  (MealDB API)
# =============================================================
FOOD_CATEGORIES: Dict[str, List[str]] = {
    "Happy":   ["Seafood",    "Dessert",       "Chicken",  "Pasta"],
    "Sadness": ["Dessert",    "Pasta",         "Chicken",  "Side"],
    "Anger":   ["Beef",       "Lamb",          "Side",     "Chicken"],
    "Complex": ["Vegetarian", "Miscellaneous", "Side",     "Pasta"],
    "Stressed":["Pasta",      "Vegetarian",    "Chicken",  "Seafood"],
    "Fear":    ["Chicken",    "Vegetarian",    "Pasta",    "Side"],
    "Surprise":["Miscellaneous","Seafood",     "Dessert",  "Beef"],
    "Disgust": ["Vegetarian", "Dessert",       "Pasta",    "Side"],
}

FOOD_AREAS: Dict[str, List[str]] = {
    "Happy":   ["Turkish", "Italian",  "Japanese", "French"],
    "Sadness": ["Turkish", "British",  "French",   "Greek"],
    "Anger":   ["Mexican", "American", "Chinese",  "Indian"],
    "Complex": ["Indian",  "Greek",    "Moroccan", "Japanese"],
    "Stressed":["Italian", "Turkish",  "Japanese", "Greek"],
    "Fear":    ["British", "Turkish",  "Greek",    "Italian"],
    "Surprise":["Japanese","Mexican",  "Moroccan", "Chinese"],
    "Disgust": ["Greek",   "Italian",  "Turkish",  "French"],
}

def _meals_by_category(cat: str, n: int = 2) -> List[Dict]:
    try:
        r = requests.get(
            f"https://www.themealdb.com/api/json/v1/1/filter.php?c={cat}",
            timeout=3).json()
        if "meals" in r and r["meals"]:
            picked = random.sample(r["meals"], min(n, len(r["meals"])))
            return [{"name":  m["strMeal"],
                     "image": m["strMealThumb"],
                     "link":  f"https://www.google.com/search?q={m['strMeal']}+tarifi"}
                    for m in picked]
    except:
        pass
    return []

def _meals_by_area(area: str, n: int = 1) -> List[Dict]:
    try:
        r = requests.get(
            f"https://www.themealdb.com/api/json/v1/1/filter.php?a={area}",
            timeout=3).json()
        if "meals" in r and r["meals"]:
            picked = random.sample(r["meals"], min(n, len(r["meals"])))
            return [{"name":  m["strMeal"],
                     "image": m["strMealThumb"],
                     "link":  f"https://www.google.com/search?q={m['strMeal']}+tarifi"}
                    for m in picked]
    except:
        pass
    return []

def get_food_list(mood: str) -> List[Dict]:
    cats  = FOOD_CATEGORIES.get(mood, ["Miscellaneous"])[:]
    areas = FOOD_AREAS.get(mood, ["Turkish"])[:]
    random.shuffle(cats)
    random.shuffle(areas)
    seen: Dict[str, dict] = {}
    for cat in cats[:3]:
        for meal in _meals_by_category(cat, 2):
            if meal["name"] not in seen:
                seen[meal["name"]] = meal
    for area in areas[:2]:
        for meal in _meals_by_area(area, 2):
            if meal["name"] not in seen:
                seen[meal["name"]] = meal
    pool = list(seen.values())
    random.shuffle(pool)
    if pool:
        return pool[:4]
    return [{"name":  "Mercimek Çorbası",
             "image": "https://www.themealdb.com/images/media/meals/7v49261511112422.jpg",
             "link":  "https://www.google.com/search?q=mercimek+corbasi+tarifi"}]


# =============================================================
# 📍 6. API ENDPOINTS
# =============================================================
MESSAGES = {
    "Happy":   "Harika görünüyorsun! Enerjini koruyalım. ✨",
    "Sadness": "Hüzün de bir misafirdir. Yalnız değilsin. 💙",
    "Stressed":"Derin bir nefes al. Her şey kontrol altında. 😰",
    "Fear":    "Güvendesin. Bu his geçici. 🌿",
    "Complex": "Bazen hisler karışır. Akışına bırak, her şey netleşecek. 🌀",
    "Anger":   "Sakinleşmek güçtür. Kendine zaman ver. ⚡",
    "Disgust": "Taze bir başlangıç hak ediyorsun. Kendini iyi hissettir. 🌿",
    "Surprise":"Hayat sürprizlerle dolu! Bu anın tadını çıkar. 😲",
}

@app.post("/predict")
async def predict(request: UserRequest):
    mood, conf = get_mood_analysis(request.text)
    return {
        "status": "success",
        "analysis": {
            "mood":       mood,
            "confidence": f"%{conf*100:.1f}",
            "message":    MESSAGES.get(mood, "Seni anlıyorum, her zaman yanındayım."),
            "user_text":  request.text,
        },
        "recommendations": {
            "music": get_spotify_list(mood),
            "book":  get_book_list(mood),
            "food":  get_food_list(mood),
        },
    }

@app.post("/feedback")
async def feedback(data: FeedbackRequest):
    tarih = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(LOG_FILE, mode='a', newline='', encoding='utf-8') as f:
            csv.writer(f).writerow([tarih, data.text, data.mood, data.vote])
        return {"status": "success", "message": "Geri bildirim başarıyla loglandı."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Loglama Hatası: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        loop="asyncio",
        timeout_keep_alive=30,
    )