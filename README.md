<p align="center">
  <img src="./assets/icon.png" width="100" alt="BlackScreen icon" />
</p>

<h1 align="center">BlackScreen</h1>

<p align="center">
  Turn off your MacBook screen. Stay focused on your movie.
</p>

<p align="center">
  <a href="https://github.com/ataberkcemunal/BlackScreen/releases/latest">
    <img src="https://img.shields.io/badge/Download%20for%20macOS-BlackScreen-000000?style=for-the-badge&logo=apple&logoColor=white" />
  </a>
</p>

---

## 🎬 Why BlackScreen?

When watching movies or TV shows at night on an external monitor, your MacBook screen can create unwanted light and break immersion.

**BlackScreen fixes this instantly** by turning your built-in display completely black while keeping your external monitor fully usable.

---

## ✨ Features

- 🎬 Perfect for movies & TV shows at night
- 🖤 Blacks out the built-in MacBook display
- 🖥️ Keeps external monitors fully usable
- 🌙 Eliminates distracting screen glow
- ⚡ Lightweight native macOS app (Swift)
- 🎬 Smooth fade-in and fade-out
- 👆 Click anywhere to exit  

---

## ⚙️ Usage

- Open BlackScreen  
- Your MacBook display goes completely black  
- External monitor remains active  
- Click anywhere on the black screen to exit  

---

## 🚀 Installation

1. Download **BlackScreen.dmg**  
2. Open the DMG file  
3. Drag **BlackScreen.app** into **Applications**  
4. Launch the app  

---

## ⚠️ First Launch (Important)

BlackScreen is currently **unsigned**, so macOS may show:

> “App is damaged and can’t be opened”

This is normal. To fix it, run:

```bash
# Remove macOS quarantine
xattr -cr /Applications/BlackScreen.app

# Launch the app
open /Applications/BlackScreen.app
```

---

## 🛠️ Build from source

```bash
./build.sh  
open BlackScreen.app
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
