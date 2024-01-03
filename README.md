# VolumeButtonManager

`VolumeButtonManager` is a Swift class designed to manage the device's volume buttons and update the app's state accordingly. This utility class is particularly useful for scenarios where your application needs to respond to changes in the device's volume.

## Table of Contents
- [VolumeButtonManager](#volumebuttonmanager)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Contribution](#contribution)
  - [License](#license)

## Overview

The `VolumeButtonManager` class encapsulates the logic for handling volume changes, utilizing the `AVAudioSession` and `MPVolumeView` APIs. It provides methods to start and stop the manager, as well as configuring the initial volume level and adjusting it within specified bounds. The class observes volume changes and triggers actions accordingly.

## Installation

To integrate `VolumeButtonManager` into your Swift Package Manager-enabled project, add the following to your `Package.swift` file:

```swift
// ...

dependencies: [
    .package(url: "https://github.com/lucaArchidiacono/VolumeButtonManager.git", from: "1.0.0"),
],

targets: [
    .target(
        name: "YourTarget",
        dependencies: ["VolumeButtonManager"]),
    // ...
]
```

## Usage

To use the VolumeButtonManager, simply create an instance of the class, and the manager will start automatically. Optionally, you can provide a closure to the onAction property, which will be executed whenever a volume button press is detected.


```swift
import VolumeButtonManager

let volumeManager = VolumeButtonManager()
volumeManager.onAction = {
    // Handle volume button press
    print("Volume button pressed!")
}

// Optionally, stop the manager
volumeManager.stop()
```

## Contribution

Feel free to contribute to the project by submitting bug reports, feature requests, or pull requests. Your input is valuable!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
