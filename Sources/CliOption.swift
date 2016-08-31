//
//  CliOption.swift
//  CliRunnable
//
//  Created by Joel Saltzman on 8/27/16.
//
//

import Foundation

public struct CliOptionGroup {
    public let description: String
    public var options = [CliOption]()
    public func filterInvalidKeys(arguments:[String], environment:[String:String]) throws -> [CliOption] {
        return try options.flatMap{ try $0.validateKeys(arguments: arguments, environment: environment) }
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
public struct CliOption : Equatable {
    public var keys: [String]
    public var description: String
    public var requiredArguments: [CliOption]?
    public var optionalArguments: [CliOption]?
    public var requiresValue: Bool = true //as in if the key is -a does it require a value after it (ps `-a` does not require a value)
    public var defaultValue: String?
    public var values: [String]?
    public var action: ((CliOption) throws -> Void)?
    
    public init(keys:[String], description:String, requiresValue:Bool = true, defaultValue:String? = nil) {
        self.keys = keys
        self.description = description
        self.requiresValue = requiresValue
        self.defaultValue = defaultValue
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
    public func validateKeys(arguments:[String], environment:[String:String]) throws -> CliOption? {
        //check if the keys have been used
        if !keys.reduce(false, { (result, key) -> Bool in result || arguments.contains(key) }){
            if !environment.keys.reduce(false, { (result, key) -> Bool in
                return result || keys.contains(key) }) && defaultValue == nil {
                return nil
            }
        }
        if let requiredArgs = requiredArguments {
            for requiredOption in requiredArgs {
                if try requiredOption.validateKeys(arguments: arguments, environment: environment) == nil {
                    throw CliRunnableError.missingRequiredArgument(keys: requiredOption.keys)
                }
            }
        }
        if let optionalArgs = optionalArguments {
            let validatedArgs = try optionalArgs.flatMap{ try $0.validateKeys(arguments: arguments, environment: environment) }
            if validatedArgs.count != optionalArgs.count {
                //not all optional args were used, return updated version without those args
                var copy = self
                copy.optionalArguments = validatedArgs
                return copy
            }
        }
        return self
    }
    
    public func parseValues(using delimiters:[String], arguments:[String], environment:[String:String]) throws -> CliOption {
        var copy = self
        //check args
        if let start = arguments.index(where:{ keys.contains($0) }) {
            let section = arguments[start..<arguments.count]
            if let end = section.index(where:{ $0 != section.first && delimiters.contains($0) }) {
                copy.values = Array(section[start+1..<end])
            }else{
                //didn't find a key scanning to the end, use all the rest
                copy.values = Array(section[start+1..<section.endIndex])
            }
        }
        //check environment
        let envValues = keys.flatMap{ environment[$0] }
        if envValues.count > 0 {
            copy.values = envValues
        }
        //no values yet, use the defaults if we have them
        if copy.values == nil, let defaultValue = copy.defaultValue {
            copy.values = [defaultValue]
        }
        //still no values, if it requires a value, throw
        if copy.values == nil && requiresValue {
            throw CliRunnableError.missingRequiredValue(keys: keys)
        }//else it might be an option like ps `-a` that doesn't require anything after it
        
        //check requiredArguments
        if let reqArguments = requiredArguments {
            copy.requiredArguments = try reqArguments.map{ try $0.parseValues(using:delimiters, arguments:arguments, environment:environment)}
        }
        
        //check optionalArguments
        if let optArguments = optionalArguments {
            copy.optionalArguments = try optArguments.map{ try $0.parseValues(using:delimiters, arguments:arguments, environment:environment)}
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
