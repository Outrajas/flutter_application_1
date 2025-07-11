import os
import pandas as pd
import numpy as np
import json
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Embedding, Conv1D, GlobalMaxPooling1D, Dense, Dropout
from tensorflow.keras.preprocessing.text import Tokenizer
from tensorflow.keras.preprocessing.sequence import pad_sequences
from sklearn.model_selection import train_test_split
from sklearn.utils import class_weight
import shutil

# === Paths ===
assets_dir = r"C:\Users\ojasa\Documents\flutter_application_1\assets"
model_path = os.path.join(assets_dir, "pdf_cleaner_model.tflite")
tokenizer_path = os.path.join(assets_dir, "tokenizer.json")
model_weights_path = os.path.join(assets_dir, "model_weights.h5")
training_data_dir = r"C:\Users\ojasa\Downloads\train_server\training_data"
export_dir = r"C:\Users\ojasa\Downloads\train_server\models"

max_len = 100

def load_existing_tokenizer():
    if os.path.exists(tokenizer_path):
        try:
            with open(tokenizer_path, "r", encoding="utf-8") as f:
                tokenizer_data = json.load(f)
                tok = Tokenizer(oov_token=tokenizer_data.get("oov_token", "<OOV>"))
                tok.word_index = tokenizer_data.get("word_index", {})
                return tok
        except Exception as e:
            print(f"⚠️ Failed loading tokenizer: {e}")
    return None

def main():
    print("📊 Training on ALL CSV files...\n")
    csv_files = [f for f in os.listdir(training_data_dir) if f.endswith(".csv")]
    if not csv_files:
        print("❌ No CSV files found.")
        return

    all_texts, all_labels = [], []

    for csv_file in csv_files:
        path = os.path.join(training_data_dir, csv_file)
        try:
            df = pd.read_csv(path)
            df = df.dropna(subset=["line", "label"])
            df = df[df["label"].isin([0, 1])]
            if df.empty:
                continue
            all_texts.extend(df["line"].astype(str).tolist())
            all_labels.extend(df["label"].astype(int).tolist())
            print(f"✅ Loaded: {csv_file} ({len(df)} rows)")
        except Exception as e:
            print(f"❌ Failed to read {csv_file}: {e}")

    if not all_texts:
        print("❌ No valid data found in any file.")
        return

    tokenizer = load_existing_tokenizer()
    if tokenizer:
        print("🔄 Updating existing tokenizer...")
        tokenizer.fit_on_texts(all_texts)
    else:
        print("🆕 Creating new tokenizer...")
        tokenizer = Tokenizer(oov_token="<OOV>")
        tokenizer.fit_on_texts(all_texts)

    X = pad_sequences(tokenizer.texts_to_sequences(all_texts), maxlen=max_len)
    y = np.array(all_labels)

    if len(X) < 2:
        print("❌ Not enough data.")
        return

    X_train, X_test, y_train, y_test = train_test_split(X, y, stratify=y, test_size=0.1)
    class_weights = dict(enumerate(class_weight.compute_class_weight("balanced", classes=np.unique(y_train), y=y_train)))

    vocab_size = len(tokenizer.word_index) + 1
    model = Sequential([
        Embedding(vocab_size, 64, input_length=max_len),
        Conv1D(64, 5, activation="relu"),
        GlobalMaxPooling1D(),
        Dense(64, activation="relu"),
        Dropout(0.3),
        Dense(1, activation="sigmoid")
    ])
    model.compile(loss="binary_crossentropy", optimizer="adam", metrics=["accuracy"])
    if os.path.exists(model_weights_path):
        print("🔁 Loading previous weights...")
        model.load_weights(model_weights_path)

    print("🚀 Training model...")
    model.fit(X_train, y_train, epochs=10, batch_size=32, validation_data=(X_test, y_test), class_weight=class_weights)

    acc = model.evaluate(X_test, y_test)[1]
    print(f"✅ Final Accuracy: {acc:.2%}")

    # Export TFLite model
    tflite_model = tf.lite.TFLiteConverter.from_keras_model(model).convert()
    with open(model_path, "wb") as f:
        f.write(tflite_model)
    print(f"💾 TFLite model saved: {model_path}")

    model.save_weights(model_weights_path)
    print(f"💾 Weights saved: {model_weights_path}")

    with open(tokenizer_path, "w", encoding="utf-8") as f:
        json.dump({
            "word_index": tokenizer.word_index,
            "oov_token": tokenizer.oov_token
        }, f, ensure_ascii=False, indent=2)
    print(f"✅ Tokenizer saved: {tokenizer_path}")

    # === Copy to models export dir ===
    os.makedirs(export_dir, exist_ok=True)
    shutil.copy(model_path, os.path.join(export_dir, "pdf_cleaner_model.tflite"))
    shutil.copy(tokenizer_path, os.path.join(export_dir, "tokenizer.json"))
    shutil.copy(model_weights_path, os.path.join(export_dir, "model_weights.h5"))
    print(f"📦 Model + Tokenizer also exported to: {export_dir}")

if __name__ == "__main__":
    main()
