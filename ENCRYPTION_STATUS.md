# Encryption Status - IMPORTANT UPDATE

## Current Status: Files May Not Be Encrypted By App

After extensive analysis, the boot.img4 and diags files in `/Resources/RES/LIBRARY/` may NOT be encrypted by the application itself. Here's why:

### Evidence

1. **No Valid Decryption Found**
   - Tested all reasonable passphrases from decompile
   - No IMG4 markers found after any decryption attempt  
   - All "decrypted" outputs show 256/256 unique bytes (perfect entropy = still encrypted)

2. **Possible Explanations**

   **Option A: Files are Apple-Encrypted IMG4 (Most Likely)**
   - Files are standard Apple IMG4 boot images
   - Encrypted with Apple's own keys (not app-level encryption)
   - Sent to device AS-IS via `irecovery -f`
   - T2 chip decrypts them using hardware keys
   - App never decrypts them

   **Option B: Double Encryption**
   - Files encrypted by Apple AND by app
   - Would need Apple keys first, then app passphrase
   - Less likely

   **Option C: Different Algorithm**
   - Not AES-256-ECB as assumed
   - Different key derivation
   - Missing IV or other parameters

### What This Means

The `decryptBootImageAtPath` function in the decompile might be:
- Never actually called in normal workflow
- Used for a different purpose
- Legacy code from development
- Or uses parameters we haven't found yet

### Recommendation

**For Security Research:**
1. Try using the encrypted files AS-IS with irecovery
2. The T2 chip likely handles decryption
3. Focus analysis on the serial port protocol, not file encryption

**Files to keep:**
- `/Resources/RES/LIBRARY/` - Original encrypted/Apple-signed files (KEEP AS-IS)
- Decryption may not be necessary for understanding the workflow

### Next Steps

1. Test if `irecovery -f boot.img4` works with encrypted file
2. Focus on serial port protocol analysis
3. Document what we DO know: gaster exploit, irecovery usage, serial commands

---

**Status:** Encryption unknown/unnecessary
**Date:** 2026-01-10
**Conclusion:** Files likely sent to device as-is (encrypted by Apple)
