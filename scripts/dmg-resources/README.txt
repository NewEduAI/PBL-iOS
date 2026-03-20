╔══════════════════════════════════════════════════════╗
║            PBL Zone - Installation Guide             ║
╚══════════════════════════════════════════════════════╝

1. Drag "PBL Zone.app" to the Applications folder.

2. Open the app. macOS will show a warning:
   "PBL Zone cannot be opened because it is from an
    unidentified developer."

3. To fix this:
   a) Open System Settings > Privacy & Security
   b) Scroll down — you'll see:
      "PBL Zone was blocked from use because it is
       not from an identified developer."
   c) Click "Open Anyway"
   d) Enter your password when prompted
   e) Click "Open" in the confirmation dialog

4. You only need to do this once. After that, the app
   opens normally.

──────────────────────────────────────────────────────
Alternative (Terminal):
  Open Terminal and paste this command:

  sudo xattr -dr com.apple.quarantine "/Applications/PBL Zone.app"

  Enter your password, then open the app as usual.
──────────────────────────────────────────────────────
