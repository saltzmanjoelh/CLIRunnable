//
//  CLIRunnable.swift
//  XcodeHelper
//
//  Created by Joel Saltzman on 8/20/16.
//
//

import Foundation

public enum CLIRunnableError: Error, CustomStringConvertible {
    case missingRequiredArgument(keys:[String])
    case missingRequiredValue(keys:[String])
    public var description : String {
        get {
            switch (self) {
            case let .missingRequiredArgument(keys): return String(describing: keys)
            case let .missingRequiredValue(keys): return String(describing: keys)
            }
        }
    }
}

public protocol CLIRunnable {
    var description: String? { get }//include "usage: ..." here if you want
    var cliOptionGroups: [CLIOptionGroup] { get }
}
extension CLIRunnable {
    //TODO: add tab formatting
    public func printHelp(cliOptionGroups:[CLIOptionGroup]) {
        if let desc = description {
            print(desc)
        }
        cliOptionGroups.forEach { (optionGroup) in
            let optionDescriptions = optionGroup.options.flatMap{ (cliOption:CLIOption) -> String? in
                if let desc = cliOption.description {
                    return "\t\(cliOption.keys.joined(separator: "|"))\t\(desc)"
                } else {
                    return nil
                }
            }
            if let groupDescription = optionGroup.description {
                print("\(groupDescription)\n\(optionDescriptions.joined(separator: "\n"))")
            }
            
        }
    }
    public func run(arguments:[String], environment:[String:String]) {
        do {
            let optionGroups = cliOptionGroups
            //Iterate each CLIOptionGroup's options and let them parse the args. If they find invalid args they (the CLIOption) will throw.
            //If they (the CLIOption) are optional and aren't fulfiled, they will be filtered out
            let options = try cliOptionGroups.flatMap{ try $0.filterInvalidKeys(arguments: arguments, environment: environment) }
            if options.count > 0 {
                let allKeys = options.flatMap{ $0.allKeys }
                let parsedOptions = try options.map{try $0.parseValues(using:allKeys, arguments:arguments, environment:environment)}
                try parsedOptions.forEach{
                    if let action = $0.action {
                        try action($0) //calling self.action?
                    }
                }
            } else {
                printHelp(cliOptionGroups: optionGroups)
            }
        } catch let e {
            print(String(describing: e))
        }
    }
}
