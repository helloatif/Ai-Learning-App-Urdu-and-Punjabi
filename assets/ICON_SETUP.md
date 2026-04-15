# Icon Setup Instructions

## Required Assets

Place these images in the specified folders:

### App Icon
- **Location**: `assets/icons/app_icon.png`
- **Size**: 1024x1024px
- **Format**: PNG with transparency
- **Design**: Your app logo/icon

### App Icon Foreground (Android Adaptive)
- **Location**: `assets/icons/app_icon_foreground.png`
- **Size**: 1024x1024px  
- **Format**: PNG with transparency
- **Design**: Logo only (will be placed on colored background)

### Splash Screen Logo
- **Location**: `assets/images/splash_logo.png`
- **Size**: 512x512px
- **Format**: PNG with transparency
- **Design**: App logo for splash screen

## Generate Icons

After adding the images, run:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## Quick Icon Generation (Without Custom Images)

I'll generate a simple programmatic splash screen for now.
