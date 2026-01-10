#!/usr/bin/env python3
"""
Decrypt boot.img4 and diags files from T2BoysSN-Changer
Based on parameters found in decompile analysis

✓ PASSPHRASE FOUND: T2BOYSSNCHANGER
"""

import hashlib
import os
from pathlib import Path
from Crypto.Cipher import AES
from Crypto.Hash import SHA1
from Crypto.Protocol.KDF import PBKDF2

# Encryption parameters from decompile analysis
SALT = b"ECEJWQXAIFQGCI"
PASSPHRASE = b"T2BOYSSNCHANGER"  # Found through systematic testing!
ITERATIONS = 10000
KEY_LENGTH = 32  # AES-256

def derive_key(passphrase, salt):
    """Derive AES key using PBKDF2-HMAC-SHA1"""
    return PBKDF2(passphrase, salt, dkLen=KEY_LENGTH, count=ITERATIONS, hmac_hash_module=SHA1)

def decrypt_file(encrypted_path, decrypted_path, key):
    """Decrypt a file using AES-256-ECB"""
    with open(encrypted_path, 'rb') as f:
        encrypted_data = f.read()

    # AES-256-ECB decryption
    cipher = AES.new(key, AES.MODE_ECB)
    decrypted_data = cipher.decrypt(encrypted_data)

    # Remove PKCS7 padding
    padding_length = decrypted_data[-1]
    decrypted_data = decrypted_data[:-padding_length]

    with open(decrypted_path, 'wb') as f:
        f.write(decrypted_data)

    print(f"✓ Decrypted: {encrypted_path} -> {decrypted_path}")
    return True

def main():
    # Derive the decryption key
    print(f"="*70)
    print(f"T2BoysSN-Changer boot.img4 / diags Decryptor")
    print(f"="*70)
    print(f"\nEncryption Parameters:")
    print(f"  Algorithm: AES-256-ECB")
    print(f"  Key Derivation: PBKDF2-HMAC-SHA1")
    print(f"  Salt: {SALT.decode()}")
    print(f"  Passphrase: {PASSPHRASE.decode()}")
    print(f"  Iterations: {ITERATIONS:,}")
    print(f"\nDeriving key...")

    key = derive_key(PASSPHRASE, SALT)
    print(f"  Key (hex): {key.hex()}\n")

    library_path = Path("/Users/rhcp/SN_CHANGE/Resources/RES/LIBRARY")
    output_path = Path("/Users/rhcp/SN_CHANGE/Decrypted")
    output_path.mkdir(exist_ok=True)

    # Decrypt boot.img4
    boot_img = library_path / "boot.img4"
    if boot_img.exists():
        print("Decrypting boot.img4...")
        decrypt_file(boot_img, output_path / "boot.img4", key)

        # Verify it's valid IMG4
        with open(output_path / "boot.img4", 'rb') as f:
            data = f.read(100)
            if data[0] == 0x30:
                print(f"  ✓ Valid IMG4 format (ASN.1 SEQUENCE)\n")
            elif b"IM4P" in data or b"IMG4" in data:
                print(f"  ✓ Contains IMG4 markers\n")

    # Decrypt all diags files
    bootchains_path = library_path / "bootchains"
    if bootchains_path.exists():
        print("Decrypting model-specific diags files...")
        for model_dir in sorted(bootchains_path.iterdir()):
            if model_dir.is_dir():
                diags_file = model_dir / "diags"
                if diags_file.exists():
                    model_output = output_path / "bootchains" / model_dir.name
                    model_output.mkdir(parents=True, exist_ok=True)
                    decrypt_file(diags_file, model_output / "diags", key)

    print(f"\n{'='*70}")
    print(f"✓ All files decrypted successfully!")
    print(f"{'='*70}")
    print(f"\nOutput directory: {output_path}")
    print(f"\nFiles are Apple IMG4 format (signed boot images for T2 chips)")

if __name__ == "__main__":
    main()
