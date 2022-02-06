# Tuist's SwiftLint plugin

A plugin that extends [Tuist](https://github.com/tuist/tuist) with [SwiftLint](https://github.com/realm/SwiftLint) functionalities.

## Install

In order to tell Tuist you'd like to use SwiftLint plugin in your project:

**1. Update your `Config.swift` manifest file with a referance to the plugin:**

```swift
import ProjectDescription

let config = Config(
    plugins: [
        .git(url: "https://github.com/tuist/tuist-plugin-swiftlint.git", tag: "0.0.1"),
    ]
)
```

You can read more about Tuist's `Config.swift` manifest file [here](https://docs.tuist.io/manifests/config).

**2. Fetch the plugin:**

```bash
tuist fetch
```

You can read more about the fetch command [here](https://docs.tuist.io/commands/dependencies).

**3. Run the plugin:**

```bash
tuist swiftlint
```

You can read more about plugins [here](https://docs.tuist.io/plugins/using-plugins).

## Contribute

To start working on the project, you can follow the steps below:
1. Clone the project.
2. Run `Package.swift` file. 
