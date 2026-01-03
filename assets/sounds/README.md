# Sound Assets

## Required Files

- **tick.mp3** - Countdown tick sound

### How to Add tick.mp3

You can:
1. Download a free beep/tick sound from [Pixabay](https://pixabay.com/sound-effects/search/beep/) or [Freesound](https://freesound.org/)
2. Use a simple 0.1-0.3 second "beep" or "tick" sound
3. Name it `tick.mp3` and place it in this directory

### Temporary Alternative

If you don't want to add a sound file immediately, you can comment out the audio line in `map_screen.dart`:

```dart
// _audioPlayer.play(AssetSource('sounds/tick.mp3'));
```

The countdown will still work visually without sound.
