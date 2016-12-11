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
public struct CliOption : Equatable, CustomStringConvertible {
    public var keys: [String]
    public var description: String
    public var usage: String?
    public var requiredArguments: [CliOption]?
    public var optionalArguments: [CliOption]?
    public var requiresValue: Bool = true //as in if the key is -a does it require a value after it (ps `-a` does not require a value)
    public var defaultValue: String?
    public var values: [String]?
    public var action: ((CliOption) throws -> Void)?
    
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
        //check if the keys have been used in the arguments or environment.
        if !keys.reduce(false, { (result, key) -> Bool in result || arguments.contains(key.lowercased()) }){
            if !environment.keys.reduce(false, { (result, key) -> Bool in
                return result || keys.contains(key.uppercased()) }) && defaultValue == nil {
                return nil //this option wasn't used, remove it
            }
        }
        //this option was used, make sure it has requiredArguments fulfilled
        if let requiredArgs = requiredArguments {
            for requiredOption in requiredArgs {
                if try requiredOption.validateKeys(arguments: arguments, environment: environment) == nil {
                    //TODO: have better error messages than "You didn't provide: ["-v", "--version", "GIT_TAG_VERSION"]", we need to know if it's a command or option
                    throw CliRunnableError.missingRequiredArgument(keys: requiredOption.keys)
                }
            }
        }
        //if it had any optional arguments, get them
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
        //find the first argument that matches one of this option's keys
        if let start = arguments.index(where:{ $0.lowercased() == $0 && keys.contains($0) }) { //found one
            let section = arguments[start..<arguments.count] //split the args from the found delimiter to the end of the args
            //get all args from the start through until we find any other delimiter
            if let end = section.index(where:{ $0 != section.first && $0.lowercased() == $0 && delimiters.contains($0) }) {
                //found another delimiter (startDelimiter, value, value, anotherDelimiter)
                copy.values = Array(section[start+1..<end])
            }else{
                //didn't find a key scanning to the end, use all the rest (startDelimiter, value, value)
                let endValues = Array(section[start+1..<section.endIndex])
                if endValues.count > 0 {
                    copy.values = endValues
                }
            }
        }
        //check environment for UPPERCASED keys only
        let envValues = keys.flatMap{ $0.uppercased() == $0 ? environment[$0] : nil }
        if envValues.count > 0 {
            copy.values = envValues
        }
        //no values yet, use the defaults if we have them
        if copy.values == nil || copy.values!.count == 0, let defaultValue = copy.defaultValue {
            copy.values = [defaultValue]
        }
        else if copy.values == nil && !copy.requiresValue {
            //No values provided but the option doesn't require any. Add an empty set so the argument shows as valid
            copy.values = [String]()
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

