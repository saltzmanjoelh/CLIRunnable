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
    var appName: String { get }
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
        
        entries += [HelpEntry(description: "Run `\(appName) COMMAND (\(helpKeys().joined(separator: " or ")))` for more information on a command.")]
        
        return entries
    }
    public func detailedHelpEntries(option:CliOption) -> [HelpEntry] {
        var helpEntries = [HelpEntry]()
        //include the usage before the option
        if let optionUsage = option.usage {
            helpEntries.append(HelpEntry(description: "Usage: \(optionUsage)\n"))
        }
        //add the option, it's required and optional args are added automatically
        helpEntries.append(HelpEntry(with: option, includeSubOptions: true))
        return helpEntries
    }
    public func parseHelpOption(cliOptionGroups:[CliOptionGroup], arguments: [String]) -> CliOption? {
        // /path/to/xchelper xchelper `fetch-packages` help
        //make sure we 3 args and the last one is help
        guard arguments.count == 3, helpKeys().contains(arguments.last!) else {
            return nil
        }
        //find the first root option (command) that matches the string
        return cliOptionGroups.flatMap{
            if let option = $0.options.first(where: { $0.keys.contains(arguments[1]) }) {
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
            
            if options.count > 0, let lastArgument = arguments.last, !helpKeys().contains(lastArgument), lastArgument != arguments.first! {
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
        //we pass in allKeys as a list of possible delimiters so that we can parse out the CLIOption's keys from the list (delimiter1 value targetDelimiter value delimiter2)
        let parsedOptions = try options.map{try $0.parseValues(using:allKeys, arguments:arguments, environment:environment)}
        try parsedOptions.forEach{
            if let action = $0.action {
                try action($0) //calling self.action?
            }
        }
    }
}
