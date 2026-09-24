//
//  FireMain.swift
//  Fire
//

import AppKit

@main
struct FireMain {
    static func main() {
        let args = CommandLine.arguments
        if args.count > 1 {
            switch args[1] {
            case "--install", "--register-input-source":
                exit(InputSource.shared.registerInputSource() ? EXIT_SUCCESS : EXIT_FAILURE)
            case "--enable-input-source":
                exit(InputSource.shared.enableInputSource() ? EXIT_SUCCESS : EXIT_FAILURE)
            case "--select-input-source":
                exit(InputSource.shared.selectInputSource() ? EXIT_SUCCESS : EXIT_FAILURE)
            default:
                break
            }
        }
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
