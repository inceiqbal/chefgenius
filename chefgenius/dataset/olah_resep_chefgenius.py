import pandas as pd
import ast
import json
import re
import os # Untuk membaca environment variable
from supabase import create_client, Client # Import Supabase library

# --- KONFIGURASI SUPABASE ---
# AMBIL DARI ENVIRONMENT VARIABLE ATAU ISI LANGSUNG (tapi kurang aman)
supabase_url = "https://zfiyfhmsuhitytsuioml.supabase.co" # URL Project Anda
supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmaXlmaG1zdWhpdHl0c3Vpb21sIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDY5OTI1NSwiZXhwIjoyMDc2Mjc1MjU1fQ.yCByJvGUWgL36Fp07P7hO6pFgCc0mDtgO2Yi6qH4gQ0" # <-- GANTI INI! WAJIB!
# ---------------------------

# Konfigurasi file (tidak berubah)
input_csv_file = 'Food Ingredients and Recipe Dataset with Image Name Mapping.csv'
supabase_project_ref = 'zfiyfhmsuhitytsuioml' # Hanya untuk URL gambar
supabase_image_bucket = 'recipe-images'
# --------------------

# --- CARI SERVICE ROLE KEY ---
# 1. Buka Supabase Dashboard > Project Settings > API
# 2. Scroll ke bawah ke "Project API keys"
# 3. Di bawah 'service_role (secret)', klik "Reveal", lalu copy key tersebut.
#    (Di dashboard baru, mungkin ada di tab "API Keys" > 'backend_api' (secret))
# 4. PASTE KEY TERSEBUT MENGGANTIKAN "MASUKKAN_SERVICE_ROLE_KEY_ANDA_DI_SINI"
# ---------------------------

if supabase_key == "MASUKKAN_SERVICE_ROLE_KEY_ANDA_DI_SINI":
    print("ERROR: Anda belum memasukkan SUPABASE_SERVICE_KEY di dalam skrip!")
    print("Cari service_role key di Supabase Dashboard > Project Settings > API.")
    exit()

print("Menghubungkan ke Supabase...")
try:
    supabase: Client = create_client(supabase_url, supabase_key)
    print("Berhasil terhubung ke Supabase.")
except Exception as e:
    print(f"Gagal terhubung ke Supabase: {e}")
    exit()

print(f"Membaca file: {input_csv_file}...")
# Coba baca dengan encoding utf-8, fallback ke latin-1
df = None
try:
    df = pd.read_csv(input_csv_file, index_col=0, encoding='utf-8')
except UnicodeDecodeError:
    print("Gagal membaca sebagai UTF-8, mencoba latin-1...")
    try:
        df = pd.read_csv(input_csv_file, index_col=0, encoding='latin-1')
    except Exception as e:
        print(f"Gagal membaca CSV: {e}")
        exit()
except FileNotFoundError:
    print(f"Error: File {input_csv_file} tidak ditemukan.")
    exit()
except Exception as e:
     print(f"Error saat membaca CSV: {e}")
     exit()

if df is None:
    print("Gagal memuat DataFrame.")
    exit()

print("Memulai proses pengolahan dan penyisipan data ke Supabase...")

# Fungsi helper tidak berubah
def safe_literal_eval(s):
    try:
        if not isinstance(s, str): return []
        s_cleaned = s.encode('ascii', 'ignore').decode('ascii')
        s_cleaned = s_cleaned.replace('\n', '').replace('\\', '').replace('""', '"')
        s_cleaned = re.sub(r"(?<!\\)'", '"', s_cleaned)
        result = ast.literal_eval(s_cleaned)
        return result if isinstance(result, list) else []
    except Exception as e:
        return []

def clean_steps(instructions):
    if not isinstance(instructions, str): return []
    try:
        instructions_ascii = instructions.encode('ascii', 'ignore').decode('ascii')
    except:
        instructions_ascii = instructions
    steps_list = instructions_ascii.strip().split('\n')
    cleaned_steps = [re.sub(r'^\s*\d+[\.\)]\s*|\s*-\s*', '', s.strip()) for s in steps_list if s.strip()]
    return cleaned_steps

# Proses data dan insert per baris
skipped_count = 0
inserted_count = 0
batch_size = 100 # Jumlah data per batch insert (bisa disesuaikan)
data_to_insert = []

for index, row in df.iterrows():
    # Ambil data dari baris
    title = str(row['Title']).strip() if pd.notna(row['Title']) else None
    ingredients_raw_str = row['Ingredients']
    steps_raw_str = row['Instructions']
    image_name = row['Image_Name']
    main_ingredients_str = row['Cleaned_Ingredients']

    # Olah data
    main_ingredients_list = safe_literal_eval(main_ingredients_str)
    main_ingredients_list = [str(item).strip() for item in main_ingredients_list if str(item).strip()]

    steps_list = clean_steps(steps_raw_str)
    steps_list = [item for item in steps_list if item]

    ingredients_list = safe_literal_eval(ingredients_raw_str)
    ingredients_list = [str(item).strip() for item in ingredients_list if str(item).strip()]
    # Kirim sebagai list python, biarkan Supabase/Postgres menangani konversi ke jsonb
    # ingredients_json_str = json.dumps(ingredients_list) if ingredients_list else '[]' 

    # Buat image URL
    base_image_url = f"https://{supabase_project_ref}.supabase.co/storage/v1/object/public/{supabase_image_bucket}/"
    image_url = base_image_url + str(image_name) + '.jpg' if pd.notna(image_name) else None

    # Filter data yang tidak valid
    if not title or not main_ingredients_list or not steps_list or not ingredients_list:
        skipped_count += 1
        continue

    # Siapkan data untuk dimasukkan (dictionary)
    recipe_data = {
        'title': title,
        'description': None, # Tetap None karena tidak ada di CSV
        'duration': None,
        'servings': None,
        'image_url': image_url,
        'ingredients': ingredients_list, # Kirim sebagai list Python
        'main_ingredients': main_ingredients_list, # Kirim sebagai list Python
        'steps': steps_list # Kirim sebagai list Python
    }
    data_to_insert.append(recipe_data)

    # Jika batch sudah penuh, insert ke Supabase
    if len(data_to_insert) >= batch_size:
        try:
            print(f"Memasukkan batch {len(data_to_insert)} data...")
            supabase.table('recipes').insert(data_to_insert).execute()
            inserted_count += len(data_to_insert)
        except Exception as e:
            print(f"Gagal memasukkan batch data: {e}")
        finally:
            data_to_insert = [] # Kosongkan batch

# Insert sisa data terakhir (jika ada)
if data_to_insert:
    try:
        print(f"Memasukkan sisa {len(data_to_insert)} data...")
        supabase.table('recipes').insert(data_to_insert).execute()
        inserted_count += len(data_to_insert)
    except Exception as e:
        print(f"Gagal memasukkan sisa data: {e}")

print("-" * 30)
print("SELESAI!")
print(f"Total baris dibaca: {len(df)}")
print(f"Resep dilewati (data tidak valid): {skipped_count}")
print(f"Resep berhasil dimasukkan ke Supabase: {inserted_count}")
print("-" * 30)