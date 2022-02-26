# Tuist SwiftLint plugin

A plugin that extends [Tuist](https://github.com/tuist/tuist) with [SwiftLint](https://github.com/realm/SwiftLint) functionalities.

## Install

In order to tell Tuist you'd like to use SwiftLint plugin in your project follow the instructions that are described in [Tuist documentation](https://docs.tuist.io/plugins/using-plugins).

## Usage

The plugin provides a command for linting the Swift code of your projects by leveraging [SwiftLint](https://github.com/realm/SwiftLint). All you need to do is run the following command:

```
tuist lint
```

You can lint selected target by specifing its name:

```
tuist lint MyTarget
```

### Arguments

| Argument   | Short  | Description  | Default  | Required  |
|:-:|:-:|:-:|:-:|:-:|
| `--path`  | `-p`  | The path to the directory that contains the workspace or project whose code will be linted.  | Current directory  | No  |

For additional help you can call:

```
tuist lint --help
```

### Subcommands

| Subcommand  | Description  |
|:-|:-|
| `tuist lint version-swiftlint`  | Outputs the current version of SwiftLint.  |
| `tuist lint version`  | Outputs the current version of the plugin.  |

## Contribute

To start working on the project, you can follow the steps below:
1. Clone the project.
2. Run `Package.swift` file. 
