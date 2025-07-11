import fitz  # PyMuPDF
import tensorflow as tf
import numpy as np
import json
import os
import re
from tensorflow.keras.preprocessing.sequence import pad_sequences

# === CONFIGURATION ===
MODEL_PATH = "models/pdf_cleaner_model.tflite"
TOKENIZER_PATH = "models/tokenizer.json"
INPUT_FOLDER = "test_books"
MAX_LEN = 100
CLEANED_TXT = r"C:\Users\ojasa\Downloads\sample_cleaned.txt"
REMOVED_TXT = r"C:\Users\ojasa\Downloads\sample_removed.txt"

# === Load tokenizer ===
with open(TOKENIZER_PATH, "r", encoding="utf-8") as f:
    tokenizer_data = json.load(f)

# Ensure tokenizer_data is valid
if not isinstance(tokenizer_data, dict) or "word_index" not in tokenizer_data:
    raise ValueError("❌ Invalid tokenizer format. Expected a dictionary with 'word_index'.")

word_index = tokenizer_data["word_index"]
oov_token = tokenizer_data.get("oov_token", "<OOV>")
oov_index = word_index.get(oov_token, 1)

# === Load TFLite model ===
interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()
input_index = interpreter.get_input_details()[0]['index']
output_index = interpreter.get_output_details()[0]['index']

# === Helper functions ===
def clean_text(text):
    text = text.lower()
    text = re.sub(r"[^\w\s.,;?!]", "", text)
    return text

def text_to_sequence(text):
    words = clean_text(text).split()
    return [word_index.get(word, oov_index) for word in words]

def preprocess(text):
    seq = [text_to_sequence(text)]
    padded = pad_sequences(seq, maxlen=MAX_LEN)
    return padded.astype(np.float32)

def predict(text):
    x = preprocess(text)
    interpreter.set_tensor(input_index, x)
    interpreter.invoke()
    output = interpreter.get_tensor(output_index)
    return float(output[0][0])

# === Process PDFs ===
for file in os.listdir(INPUT_FOLDER):
    if file.endswith(".pdf"):
        pdf_path = os.path.join(INPUT_FOLDER, file)
        print(f"🔍 Reading PDF: {pdf_path}")
        
        with open(CLEANED_TXT, "w", encoding="utf-8") as clean_file, \
             open(REMOVED_TXT, "w", encoding="utf-8") as removed_file:
            
            doc = fitz.open(pdf_path)
            total_lines = 0
            cleaned_count = 0
            removed_count = 0
            
            for page_num in range(len(doc)):
                page = doc.load_page(page_num)
                text = page.get_text().split("\n")
                
                for line in text:
                    line = line.strip()
                    if not line:
                        continue
                    
                    try:
                        score = predict(line)
                        total_lines += 1
                        if total_lines % 100 == 0:
                            print(f"📊 Processed {total_lines} lines...")
                        
                        result = f"[{score:.2f}] {line}"
                        if score > 0.5:
                            cleaned_count += 1
                            clean_file.write(result + "\n")
                        else:
                            removed_count += 1
                            removed_file.write(result + "\n")
                    except Exception as e:
                        print(f"❌ Error processing line: {e}")
            
            doc.close()
            print(f"✅ Done. Total lines: {total_lines}")
            print(f"   Cleaned: {cleaned_count}, Removed: {removed_count}")
