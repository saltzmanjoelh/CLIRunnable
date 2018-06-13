//
//  Dictionary.swift
//  CliRunnable
//
//  Created by Joel Saltzman on 3/30/17.
//
//

import Foundation

public extension Dictionary {

    mutating func merge<K, V>(dictionaries: Dictionary<K, V>...) {
        for dict in dictionaries {
            for (key, value) in dict {
                self.updateValue(value as! Value, forKey: key as! Key)
            }
        }
    }
    func merged<K, V>(dictionaries: Dictionary<K, V>...) -> Dictionary {
        var result = self
        for dict in dictionaries {
            for (key, value) in dict {
                result.updateValue(value as! Value, forKey: key as! Key)
            }
        }
        return result
    }
}
