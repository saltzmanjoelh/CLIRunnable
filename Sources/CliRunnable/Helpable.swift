//
//  HelpEntry.swift
//  CliRunnable
//
//  Created by Joel Saltzman on 8/28/16.
//
//

import Foundation

public protocol Helpable {
    func helpEntries() -> [HelpEntry]
    func detailedHelpEntries(option:CliOption) -> [HelpEntry]
    var appUsage: String? { get }
}
extension Helpable {
    public func helpKeys() -> [String] {
        return ["--help", "help", "-h"]
    }
    
    public func helpString(with helpEntries:[HelpEntry]) -> String {
        let columnLength = helpEntries.reduce(0) { (maxLength, helpEntry) -> Int in
            let length = helpEntry.columnLength()
            return maxLength > length ? maxLength : length
        }
        return helpEntries.map{ $0.stringValue(padding:columnLength) }.joined(separator:"\n")
    }
}

public struct HelpEntry {
    public var value: String? = nil
    public let description: String
    public var options: [HelpEntry]? = nil
    
    public func columnLength() -> Int {
        var maxLength = 0
        if let theValue = value {
            maxLength = theValue.count
        }
        if let subOptions = options {
            maxLength = subOptions.reduce(maxLength){ (optionLength, optionEntry) -> Int in
                let length = optionEntry.columnLength()
                return optionLength > length ? optionLength : length
            }
        }
        return maxLength
    }
    public func stringValue(padding:Int) -> String {
        //VALUE
        var string = ""
        if let value = self.value {
            string += value.padding(toLength: padding, withPad: " ", startingAt: 0)
            string += "    "
        }
        //DESCRIPTION
        if self.value == nil {
            //no command, just print the full description
            string += self.description
        }else{
            //we have a command in one column, split the description and fill first column with spaces
            //max is 80 for default terminal window size
            let lines = self.splitString(description, by: 75 - padding)
            //first line just gets added, all others get a newline + padding column + 4 spaces between columns (padding+5)
            string += lines.joined(separator: "\n".padding(toLength: padding+5, withPad: " ", startingAt: 0))
        }
        //OPTIONS
        if let theOptions = options {
            string += "\n"
            string += theOptions.map{ $0.stringValue(padding: padding) }.joined(separator: "\n")
        }
        return string
    }
    func splitString(_ string: String, by length: Int) -> [String] {
        let words = string.split(separator: " ")
        var lines = [""]
        for word in words {
            if lines.last!.count + word.count <= length {
                lines[lines.count-1] = lines.last! + word + " "
            }else{
                lines.append(String(word)+" ")
            }
        }
        return lines
    }
    public init(description:String){
        self.description = description
    }
    public init(value:String, descripton:String){
        self.value = value
        self.description = descripton
    }
    public init(with optionGroup:CliOptionGroup) {
        self.description = optionGroup.description
        let optionEntries = optionGroup.options.map{ HelpEntry(with: $0) }
        if optionEntries.count > 0 {
            self.options = optionEntries
        }
    }
    public init(with option:CliOption, includeSubOptions: Bool = false) {
        self.value = option.keys.joined(separator: ", ")
        var description = "\(option.description)"
        if let defaultValue = option.defaultValue {
            description += " Defaults to: \(defaultValue)."
        }
        self.description = description
        if includeSubOptions {
            var subOptions = [CliOption]()
            if let requiredArguments = option.requiredArguments {
                subOptions += requiredArguments
            }
            if let optionalArguments = option.optionalArguments {
                subOptions += optionalArguments
            }
            if subOptions.count > 0 {
                let optionEntries = subOptions.map{ HelpEntry(with: $0) }
                if optionEntries.count > 0 {
                    self.options = optionEntries
                }
            }
        }
    }
}
