//
//  CliOptionGroup.swift
//  CliRunnable
//
//  Created by Joel Saltzman on 5/25/17.
//
//

import Foundation

/**
 A CliOptionGroup groups together a set of commands/arguments. For example, you may have a group of normal commands, a group of troubleshooting commands and a group of developer commands like in `brew --help`
 */
public struct CliOptionGroup {
    public let description: String
    public var options = [CliOption]()
    public func filterInvalidKeys(indexedArguments: [String: [String: [String]]]) throws -> [CliOption] {
        return try options.flatMap{ try $0.validateKeys(indexedArguments: indexedArguments) }
    }
    public init(description:String, options:[CliOption]? = nil){
        self.description = description
        if let theOptions = options {
            self.options = theOptions
        }
    }
    public var help: HelpEntry {
        get {
            return HelpEntry(with: self)
        }
    }
}
