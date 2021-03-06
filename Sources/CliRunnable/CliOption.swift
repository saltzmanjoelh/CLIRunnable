//
//  CliOption.swift
//  CliRunnable
//
//  Created by Joel Saltzman on 8/27/16.
//
//

import Foundation
import ProcessRunner

/**
 A CliOption can either be a command or a simple option.
 An example of a command would be the `install` arg in `brew install foobar --debug`. The command takes some optional args and has a required arg, the formula to install.
 An example of an option would be the `--debug` arg in `brew install foobar --debug`. An option example would be `-a` in `ls -a`
 */
public struct CliOption : Equatable, CustomStringConvertible {
    public var keys: [String]
    public var description: String
    public var usage: String?
    public var requiredArguments: [CliOption]?
    public var optionalArguments: [CliOption]?
    public var requiresValue: Bool = true //as in if the key is -a does it require a value after it (ps `-a` does not require a value)
    public var defaultValue: String?
    public var values: [String]?
    public var action: ((CliOption) throws -> Any)?
    
    public init(keys:[String], description:String, usage:String?, requiresValue:Bool, defaultValue:String?, optionalArguments: [CliOption]? = nil, requiredArguments: [CliOption]? = nil) {
        self.keys = keys
        self.description = description
        self.requiresValue = requiresValue
        self.defaultValue = defaultValue
        self.usage = usage
        self.optionalArguments = optionalArguments
        self.requiredArguments = requiredArguments
    }
    
    
    public var allKeys: [String] {
        get {
            var allKeys = keys
            if let reqArguments = requiredArguments {
                allKeys += reqArguments.flatMap{ $0.allKeys }
            }
            if let optArguments = optionalArguments {
                allKeys += optArguments.flatMap{ $0.allKeys }
            }
            return allKeys
        }
    }
    public var allValues: [String] {
        get {
            var allValues = [String]()
            if let theValues = values {
                allValues += theValues
            }
            if let reqArguments = requiredArguments {
                allValues += reqArguments.flatMap{ $0.allValues }
            }
            if let optArguments = optionalArguments {
                allValues += optArguments.flatMap{ $0.allValues }
            }
            return allValues
        }
    }
    
    //Used with parsing to help check if an optional arguent or required argument was used
    public var argumentIndex: [String:[String]] {
        get {
            var allArguments = [self]
            if let reqArguments = requiredArguments {
                allArguments += reqArguments
            }
            if let optArguments = optionalArguments {
                allArguments += optArguments
            }
            return allArguments.reduce([String:[String]](), { (result, option) -> [String:[String]] in
                var copy = result
                for key in option.keys {
                    copy[key] = option.values
                }
                return copy
            })
        }
    }
    
    
    public mutating func add(argument:CliOption, required:Bool = false){
        if required {
            if requiredArguments == nil {
                requiredArguments = [CliOption]()
            }
            requiredArguments?.append(argument)
        } else {
            if optionalArguments == nil {
                optionalArguments = [CliOption]()
            }
            optionalArguments?.append(argument)
        }
    }
    public func validateKeys(indexedArguments: [String: [String: [String]]], helpKeys: [String]) throws -> CliOption? {
        //check if the keys have been used in the arguments or environment.
        let foundKeys = keys.compactMap({ (key: String) -> String? in
            if helpKeys.contains(key) {
                return nil
            }
            if indexedArguments[key] != nil {
                return key
            }
            for (_, commandValues) in indexedArguments {
                if commandValues.keys.contains(key) {
                    return key
                }
            }
            return nil
        })
        guard foundKeys.count > 0 else { return nil }
        //Check for helpKeys
        for key in foundKeys {
            if let args: [String] = indexedArguments[key]?[CommandArgsKey],
                Set<String>.init(helpKeys).intersection(Set<String>(args)).count > 0{
                return nil
            }
        }
        //this option was used, make sure it has requiredArguments fulfilled
        if let requiredArgs = requiredArguments {
            for requiredOption in requiredArgs {
                if try requiredOption.validateKeys(indexedArguments: indexedArguments, helpKeys: helpKeys) == nil && requiredOption.defaultValue == nil {
                    //TODO: have better error messages than "You didn't provide: ["-v", "--version", "GIT_TAG_VERSION"]", we need to know if it's a command or option
                    throw CliRunnableError.missingRequiredArgument(keys: requiredOption.keys)
                }
            }
        }
        //if it had any optional arguments, get them
        if let optionalArgs = optionalArguments {
            let validatedArgs = try optionalArgs.compactMap{ try $0.validateKeys(indexedArguments: indexedArguments, helpKeys: helpKeys) }
            if validatedArgs.count != optionalArgs.count {
                //not all optional args were used, return updated version without those args
                var copy = self
                copy.optionalArguments = validatedArgs
                return copy
            }
        }
        return self
    }
    public func valueForKeys(indexedArguments: [String: [String: [String]]]) -> [String]? {
        for (commandKey, args) in indexedArguments {
            for (key, values) in args {
                if (key == CommandArgsKey && self.keys.contains(commandKey)) ||
                    self.keys.contains(key){
                    return values
                }
            }
        }
        return nil
    }
    public func parseValues(using delimiters:[String], indexedArguments: [String: [String: [String]]]) throws -> CliOption {
        var copy = self
        
        copy.values = valueForKeys(indexedArguments: indexedArguments)
        
        if (copy.values == nil || copy.values?.count == 0) && requiresValue {
            if let defaultValue = self.defaultValue {
                copy.values = [defaultValue]
            }else{
                throw CliRunnableError.missingRequiredValue(keys: keys)
            }
        }//else it might be an option like ps `-a` that doesn't require anything after it
        
        //check requiredArguments
        if let reqArguments = requiredArguments {
            copy.requiredArguments = try reqArguments.map{ try $0.parseValues(using: delimiters, indexedArguments: indexedArguments)}
        }
        
        //check optionalArguments
        if let optArguments = optionalArguments {
            copy.optionalArguments = try optArguments.map{ try $0.parseValues(using:delimiters, indexedArguments: indexedArguments)}
        }
        
        return copy
    }
}


public func ==(lhs:CliOption, rhs:CliOption) -> Bool {
    return lhs.keys == rhs.keys
}
public func !=(lhs: CliOption, rhs: CliOption) -> Bool {
    return lhs.keys != rhs.keys
}


