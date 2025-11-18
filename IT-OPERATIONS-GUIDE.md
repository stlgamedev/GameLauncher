# IT Operations Guide — St. Louis Science Center

**This system is designed to run automatically with ZERO maintenance needed.**

---

## 🟢 Normal Operation

When the computer boots, the launcher starts automatically and runs in fullscreen. It will:
- Show the game menu after a few seconds
- Switch to screensaver mode when idle
- Auto-restart if it crashes
- Keep running forever

---

## 🆘 Emergency Controls

If a game gets stuck or you need to force-quit:

**Press `Shift + F12`**

This immediately kills the current game and returns to the menu. Works from anywhere.

If that doesn't work: **Restart the computer.**

The launcher will start back up automatically.

---

## 🔄 Crash Loop Recovery

If the launcher keeps crashing over and over:

1. Press `Win + R`
2. Type `taskschd.msc` and press Enter
3. Find `STLGameLauncherKiosk` in the task list
4. Right-click it → **Disable**

This stops the auto-restart. Then call us (see below).

---

## 📞 When to Call Us

Only call if:
- Launcher won't stop crashing (after disabling the task above)
- Games won't launch
- Weird visual glitches
- Something is obviously broken

**Contact:** admin@stlgame.dev

---

## 💾 System Details

**Installation Location:** `C:\Program Files\STLGameLauncher`  
**Game Content:** `C:\ProgramData\STLGameLauncher\external`  
**Logs:** `C:\ProgramData\STLGameLauncher\logs`
