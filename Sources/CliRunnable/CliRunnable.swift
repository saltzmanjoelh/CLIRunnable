//
//  CliRunnable.swift
//  XcodeHelper
//
//  Created by Joel Saltzman on 8/20/16.
//
//

import Foundation
import Yaml


public protocol CliRunnable: Helpable {
    var appName: String { get }
    var description: String? { get }//include "usage: ..." here if you want
    var cliOptionGroups: [CliOptionGroup] { get }
}

//Used in the yaml configuration file to indicate the arguments for a command
/* git add /some/file
 
 add:
 args:
 - /some/file
 */
public let CommandArgsKey = "args"

public enum CliRunnableError: Error, CustomStringConvertible {
    case missingRequiredArgument(keys:[String])
    case missingRequiredValue(keys:[String])
    case unknownKeys(key: [String])
    public var description : String {
        get {
            switch (self) {
            case let .missingRequiredArgument(keys): return "You didn't provide: "+String(describing: keys)
            case let .missingRequiredValue(keys): return "You didn't provide a value for: "+String(describing: keys)
            case let .unknownKeys(keys): return "Unknown keys: "+String(describing: keys)
            }
        }
    }
}

extension CliRunnable {
    
    
    public func run(arguments:[String], environment:[String:String], yamlConfigurationPath: String? = nil) throws {
        let optionGroups = cliOptionGroups
        let mergedIndex = try consolidateArgs(arguments: arguments,
                                              environment: environment,
                                              yamlConfigurationPath: yamlConfigurationPath,
                                              optionGroups: optionGroups)
        
        //We run through all possible options to try and find
        //an option that has valid keys and doesn't throw an error.
        //If a command is found but it's required options aren't, we throw an error
        let parsedOptions = try parse(optionGroups: optionGroups, indexedArguments: mergedIndex)
        
        if parsedOptions.count > 0,
            let lastArgument = arguments.last,
            !helpKeys().contains(lastArgument),
            lastArgument != arguments.first! {
            try handleUnknownKeys(arguments: arguments, options: parsedOptions)
            
            try parsedOptions.forEach{
                if let action = $0.action {
                    try action($0) //calling self.action?
                }
            }
        } else {
            printHelp(cliOptionGroups: optionGroups, arguments: arguments)
        }
    }
    /**
     Merges all the possible inputs together. The order of precedence is yaml, environment, cli arguments.
     That means if you have an argument listed in the yaml file and differently as an evironment variable, the env var will be used.
     */
    public func consolidateArgs(arguments:[String],
                                environment:[String:String],
                                yamlConfigurationPath: String? = nil,
                                optionGroups: [CliOptionGroup]) throws -> [String: [String: [String]]] {
        //index the cli args
        let cliArguments = index(arguments: arguments, using: optionGroups)
        //index yaml args
        let yamlIndex = try parse(yamlConfigurationPath: yamlConfigurationPath)
        //Env vars should be flattened like cli args and matched against optionGroups
        let flattendEnv = environment.reduce([String](), { (result, pair) -> [String] in
            return result + [pair.key, pair.value]
        })
        let env = index(arguments: flattendEnv, using: optionGroups)
        //assuming that the first arg is the command, pull the command options from yamlIndex
        var yamlConfig = yamlIndex ?? [String: [String: [String]] ]()
        if arguments.count >= 2 {//1 for the path to the binary and 1 for the command
            let command = arguments[1]
            if let commandConfig = yamlIndex?[command] {
                yamlConfig[command] = commandConfig
            }
        }
        let envMerge = merge(env, over: yamlConfig)
        let cliMerge = merge(cliArguments, over: envMerge)
        
        //We merge everything together to get a combined list of keys and values
        //However, a yaml config can contain every possible option but we don't want to process every possible option
        //We only want what was provided via arguments or environment
        var mergeResult = [String: [String: [String]] ]()
        for (key, _) in environment {
            if let value = cliMerge[key] {
                mergeResult[key] = value
            }
        }
        for key in arguments {
            if let value = cliMerge[key] {
                mergeResult[key] = value
            }
        }
        
        return mergeResult
    }
    public func merge(_ indexedArguments: [String: [String: [String]] ], over index: [String: [String: [String]] ]?) -> [String: [String: [String]]] {
        //if we have yaml, start with that and override with cli args
        guard var result = index else { return indexedArguments }//didn't have yaml, just return cli
        for (command, commandValues) in indexedArguments {//iterate cli args
            //top level is command, iterate command args
            var commandIndex = result[command] ?? [String: [String]]()
            for (key, value) in commandValues {
                commandIndex[key] = value
            }
            result[command] = commandIndex
        }
        
        return result
    }
    
    
    //Iterate each CliOptionGroup's options and let them parse the args. If they find invalid args they (the CliOption) will throw.
    //If they (the CliOption) are optional and aren't fulfiled, they will be filtered out
    public func parse(optionGroups:[CliOptionGroup], indexedArguments: [String: [String: [String]]]) throws -> [CliOption] {
        //get all the valid keys
        let options = try cliOptionGroups.flatMap{ try $0.filterInvalidKeys(indexedArguments: indexedArguments) }
        let allKeys = options.flatMap{ $0.allKeys }
        
        //we pass in allKeys as a list of possible delimiters so that we can parse out the CLIOption's keys from the list (delimiter1 value targetDelimiter value delimiter2)
        //        print("\(allKeys)")
        return try options.map{try $0.parseValues(using:allKeys, indexedArguments: indexedArguments)}
    }
    func parseUnknownKeys(arguments: [String], validKeys: [String], values: [String]) -> [String] {
        //remove first arg from arguments, it's the path to the executable
        //remove validKeys from arguments
        //remove values from arguments
        //anything remaining is unknown
        let keys = arguments[1..<arguments.count].filter{ !validKeys.contains($0) }
        return keys.filter{ !values.contains($0) }
    }
    public func handleUnknownKeys(arguments:[String], options: [CliOption]) throws {
        let allKeys = options.flatMap{ $0.allKeys }
        let allValues = options.flatMap{ $0.allValues }
        //if we have an unknown keys, throw error and show help
        let unknownKeys = parseUnknownKeys(arguments: arguments, validKeys: allKeys, values: allValues)
        if unknownKeys.count > 0 {
            throw CliRunnableError.unknownKeys(key: unknownKeys)
        }
    }
}

// MARK: Cli Arg Parsing
extension CliRunnable {
    /*
     convert arguments into dictionary
     /binary/path command arg1 arg2 --option optionValue
     like [String: [String: [String]]]
     ["command": ["command-args": ["arg1", "arg2"]
     "--option": ["optionValue", "optionValue2"]]
     ]
     */
    public func index(arguments: [String], using optionGroups: [CliOptionGroup]) -> [String: [String: [String]] ] {
        //iterate over groups
        //when a command is hit, we check for optional and required options
        //we move the found option to index
        var result = [String: [String: [String]] ]()
        //get a list of all possible keys, removing the - or -- from the prefix
        let allKeys: [String] = optionGroups.flatMap({ $0.options.flatMap({ $0.allKeys.compactMap({ $0.strippingDashPrefix }) }) })
        optionGroups.forEach({ (optionGroup: CliOptionGroup) in
            optionGroup.options.forEach({ (option: CliOption) in
                result.merge(dictionaries: index(option: option, fromArguments: arguments.compactMap({ $0.strippingDashPrefix }), withKeys: allKeys))
                
            })
        })
        return result
    }
    //Find if an option was used in an array of args. We pass in all the possible keys from a flattened list of option.keys
    public func index(option: CliOption, fromArguments arguments: [String], withKeys keys: [String]) -> [String: [String: [String]] ] {
        //let args = arguments.flatMap({ $0.strippingDashPrefix })
        //let strippedKeys = keys.flatMap({ $0.strippingDashPrefix })
        var result = [String: [String: [String]] ]()
        guard let optionKey = option.keys.first else { return result }
        for key in option.keys {
            if let range = range(ofKey: key.strippingDashPrefix, inArguments: arguments, withKeys: keys) {
                if result[key] == nil {
                    result[key] = [String: [String]]()
                }
                result[key]?[CommandArgsKey] = Array(arguments[range.lowerBound+1..<range.upperBound])
            }
        }
        var options = [CliOption]()
        if let requiredArguments = option.requiredArguments {
            options += requiredArguments
        }
        if let optionalArguments = option.optionalArguments {
            options += optionalArguments
        }
        options.forEach { (option: CliOption) in
            for key in option.keys {
                if let range = range(ofKey: key.strippingDashPrefix, inArguments: arguments, withKeys: keys) {
                    result[optionKey]?[key] = Array(arguments[range.lowerBound+1..<range.upperBound])
                }
            }
        }
        
        return result
    }
    public func range(ofKey key: String, inArguments arguments: [String], withKeys keys: [String]) -> Range<Int>? {
        guard let position = arguments.index(of: key) else { return nil }
        //starting from postion+1, get all values between there and the next key
        let section = arguments[position..<arguments.count]
        //get all args from the start through until we find any other key
        if let end = section.index(where:{ $0 != section.first && keys.contains($0) }) {//had this "$0.lowercased() == $0", not sure why
            //found another delimiter (startDelimiter, value, value, anotherDelimiter)
            return position..<end
        }
        //didn't find a key scanning to the end, use all the rest (key, value, value)
        return position..<section.endIndex
    }
    
}
// MARK: Yaml Parsing
extension CliRunnable {
    public func parse(yamlConfigurationPath: String?) throws -> [String: [String: [String]]]? {
        guard let path = yamlConfigurationPath,
            FileManager.default.fileExists(atPath: path)
            else { return nil }
        
        let yaml = try String.init(contentsOf: URL(fileURLWithPath: path))
        guard let object = try Yaml.load(yaml).dictionary,
            let decodedYaml = decode(yamlDictionary: object)
            else { return nil }
        
        //make sure all values are arrays of values
        var result = [String: [String: [String]]]()
        for (command, commandValue) in decodedYaml {
            if let commandDictionary = commandValue as? [String: Any] {
                var resultCommandDictionary = [String: [String]]()
                for (key, value) in commandDictionary {
                    if let valueArray = value as? [String]{
                        resultCommandDictionary[key] = valueArray
                    }else{
                        resultCommandDictionary[key] = ["\(value)"]
                    }
                }
                result[command] = resultCommandDictionary
            }
        }
        
        return result
    }
    public func decode(yamlDictionary: [Yaml:Yaml]) -> [String:Any]? {
        var result = [String:Any]()
        for (yamlKey, yamlValue) in yamlDictionary {
            if case .string(let key) = yamlKey {
                result[key] = decode(yamlValue: yamlValue)
            }
        }
        return result.count > 0 ? result : nil
    }
    public func decode(yamlValue: Yaml) -> Any? {
        //        print(yamlValue)
        switch yamlValue {
        case .string(let stringValue):
            return stringValue
        case .bool(let boolValue):
            return boolValue
        case .int(let intValue):
            return intValue
        case .double(let doubleValue):
            return doubleValue
        case .array(let arrayValue):
            return arrayValue.compactMap({ decode(yamlValue: $0) })
        case .dictionary(let dictionaryValue):
            return decode(yamlDictionary: dictionaryValue)
        default:
            return nil
        }
    }
}

// MARK: Help
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
        
        entries += [HelpEntry(description: "\nRun `\(appName) COMMAND (\(helpKeys().joined(separator: " or ")))` for more information on a command.")]
        
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
        // /path/to/xchelper `fetch-packages` help
        //make sure we have 3 args and the last one is help
        guard arguments.count == 3, helpKeys().contains(arguments.last!) else {
            return nil
        }
        //find the first root option (command) that matches the string
        return cliOptionGroups.compactMap{
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
}

extension String {
    public var strippingDashPrefix: String {
        let regex = try! NSRegularExpression.init(pattern: "^-*", options: [])
        return regex.stringByReplacingMatches(in: self, options: [], range: NSRange.init(location: 0, length: self.count), withTemplate: "")
    }
}

