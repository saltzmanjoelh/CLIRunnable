import XCTest
@testable import CLIRunnable

struct FetchPackagesOption {
    static let command          = CLIOption(keys:["custom-command"],
                                            description:"Fetch the package dependencies via 'swift package fetch'",
                                            requiresValue: false)
}

class CLIRunnableTests: XCTestCase {
    
    func testValidateArgumentKeys() {
        do{
            let option = CLIOption(keys:[UUID().uuidString])
            
            let result = try option.validateKeys(arguments: option.keys, environment: ["":""])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateArgumentKeys_failure() {
        do{
            let option = CLIOption(keys:[UUID().uuidString])
            
            let result = try option.validateKeys(arguments: [""], environment: ["":""])
            
            XCTAssertNil(result)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateEnvironmentKeys() {
        do{
            let option = CLIOption(keys:[UUID().uuidString])
            
            let result = try option.validateKeys(arguments:[""], environment: [option.keys.first!:"value"])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateEnvironmentKeys_failure() {
        do{
            let option = CLIOption(keys:[UUID().uuidString])
            
            let result = try option.validateKeys(arguments:[""], environment: ["":""])
            
            XCTAssertNil(result)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testDefaultKey() {
        do{
            let option = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            
            let result = try option.validateKeys(arguments:[""], environment: ["":""])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testParseRootValue(){
        do{
            let option = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys, arguments:[option.keys.first!,value], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testParseRootValueWithSecondayOption(){
        do{
            let option = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let secondaryOption = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:false, defaultValue:"secondary")
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys+secondaryOption.keys, arguments:[option.keys.first!,value], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testEnvironmentValues(){
        do{
            let option = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys, arguments:[""], environment: [option.keys.first!:value])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testParseDefaultValue(){
        do{
            let option = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"defaultValue")
            
            let result = try option.parseValues(using:option.keys, arguments:[""], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, "defaultValue")
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testParseMissingRequiredValue(){
        do{
            let option = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:true)
            
            let _ = try option.parseValues(using:option.keys, arguments:[""], environment: ["":""])
            
            XCTFail("An error should have been thrown")
            
        } catch _ {
            
        }
    }
    func testParseMutlipleValues(){
        do{
            let option = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let secondaryOption = CLIOption(keys:[UUID().uuidString], description:"", requiresValue:false, defaultValue:"secondary")
            let value1 = UUID().uuidString
            let value2 = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys+secondaryOption.keys, arguments:[option.keys.first!,value1,value2], environment: ["":""])
            
            XCTAssertEqual(result.values!, [value1, value2])
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    

    static var allTests : [(String, (CLIRunnableTests) -> () throws -> Void)] {
        return [
            ("testValidateArgumentKeys", testValidateArgumentKeys),
        ]
    }
}
