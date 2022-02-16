import ProjectDescription

let dependencies = Dependencies(swiftPackageManager: [
    .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.0.0")),
])
