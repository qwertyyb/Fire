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
            case "--enable":
                exit(InputSource.shared.enableInputSource() ? EXIT_SUCCESS : EXIT_FAILURE)
            case "--select":
                exit(InputSource.shared.selectInputSource() ? EXIT_SUCCESS : EXIT_FAILURE)
            case "--ensure-select":
                exit(InputSource.shared.ensureSelectInputSource() ? EXIT_SUCCESS : EXIT_FAILURE)
            case "--enabled":
                exit(InputSource.shared.isEnabled() ? EXIT_SUCCESS : EXIT_FAILURE)
            default:
                break
            }
        }
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
