//
//  CliRunnable.swift
//  XcodeHelper
//
//  Created by Joel Saltzman on 8/20/16.
//
//

import Foundation

public enum CliRunnableError: Error, CustomStringConvertible {
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

public protocol CliRunnable: Helpable {
    var description: String? { get }//include "usage: ..." here if you want
    var cliOptionGroups: [CliOptionGroup] { get }
}
extension CliRunnable {
    
    public func helpEntries() -> [HelpEntry] {
        var entries = [HelpEntry]()
        if let appDescription = description {
            entries.append(HelpEntry(description:"\(appDescription)\n"))
        }
        if let appUsage = self.appUsage {
            entries.append(HelpEntry(description: "Usage: \(appUsage)\n"))
        }
        entries += cliOptionGroups.map{ HelpEntry(with: $0) }
        
        return entries
    }
    public func detailedHelpEntries(option:CliOption) -> [HelpEntry] {
        var helpEntries = [HelpEntry]()
        if let optionUsage = option.usage {
            helpEntries.append(HelpEntry(description: "Usage: \(optionUsage)\n"))
        }
        
        helpEntries.append(HelpEntry(description:"\(option.description)\n"))
        if let requiredArguments = option.requiredArguments {
            helpEntries += requiredArguments.map{ HelpEntry(with: $0) }
        }
        if let optionalArguments = option.optionalArguments {
            helpEntries += optionalArguments.map{ HelpEntry(with: $0) }
        }
        return helpEntries
    }
    public func helpKeys() -> [String] {
        return ["--help", "help", "-h"]
    }
    public func parseHelpOption(cliOptionGroups:[CliOptionGroup], arguments: [String]) -> CliOption? {
        // /path/to/xchelper xchelper `fetch-packages` help
        //make sure we 4 args and the last one is help
        guard arguments.count == 4, helpKeys().contains(arguments.last!) else {
            return nil
        }
        //find the first root option (command) that matches the string
        return cliOptionGroups.flatMap{
            if let option = $0.options.first(where: { $0.keys.contains(arguments[2]) }) {
                return option
            }
            return nil
        }.first
    }
    public func printHelp(cliOptionGroups:[CliOptionGroup], arguments: [String]) {
        //check if they are asking for help on an option/command, [0] is run path, [1] is command
        if let helpOption = parseHelpOption(cliOptionGroups: cliOptionGroups, arguments: arguments) {
            print(helpString(with: detailedHelpEntries(option:helpOption)))
        }else{
            print(helpString(with: helpEntries()))
        }
    }
    public func run(arguments:[String], environment:[String:String]) {
        do {
            let optionGroups = cliOptionGroups
            let options = try cliOptionGroups.flatMap{ try $0.filterInvalidKeys(arguments: arguments, environment: environment) }
            
            if options.count > 0, let lastArgument = arguments.last, !helpKeys().contains(lastArgument)  {
                try parse(optionGroups: optionGroups, arguments: arguments, environment: environment)
            } else {
                printHelp(cliOptionGroups: optionGroups, arguments: arguments)
            }
            
        } catch let e {
            print(String(describing: e))
        }
    }
    //Iterate each CliOptionGroup's options and let them parse the args. If they find invalid args they (the CliOption) will throw.
    //If they (the CliOption) are optional and aren't fulfiled, they will be filtered out
    public func parse(optionGroups:[CliOptionGroup], arguments:[String], environment:[String:String]) throws {
        let options = try cliOptionGroups.flatMap{ try $0.filterInvalidKeys(arguments: arguments, environment: environment) }
        let allKeys = options.flatMap{ $0.allKeys }
        let parsedOptions = try options.map{try $0.parseValues(using:allKeys, arguments:arguments, environment:environment)}
        try parsedOptions.forEach{
            if let action = $0.action {
                try action($0) //calling self.action?
            }
        }
    }
}
