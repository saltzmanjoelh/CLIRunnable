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
            maxLength = theValue.characters.count
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
        var string = ""
        if let value = self.value {
            string += value.padding(toLength: padding, withPad: " ", startingAt: 0)
            string += "\t"
        }
        string += description
        if let theOptions = options {
            string += "\n"
            string += theOptions.map{ $0.stringValue(padding: padding) }.joined(separator: "\n")
        }
        return string
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
    public init(with option:CliOption, options:[CliOption]? = nil) {
        self.value = option.keys.joined(separator: ", ")
        self.description = option.description
        if let subOptions = options {
            let optionEntries = subOptions.map{ HelpEntry(with: $0) }
            if optionEntries.count > 0 {
                self.options = optionEntries
            }
        }
        
    }
}
