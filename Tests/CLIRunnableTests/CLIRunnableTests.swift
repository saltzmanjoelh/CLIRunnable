import XCTest
@testable import CliRunnable

class CliRunnableTests: XCTestCase {
    
    
    
    struct App : CliRunnable {
        var appName: String = "Test App"
        var description: String? = "My CliRunnable App's description"
        public var appUsage: String? = "app COMMAND [OPTIONS]"
        
        public var cliOptionGroups: [CliOptionGroup]
        
        var command = CliOption(keys:["test-command"], description:"Test a custom command", usage: "app test-command [OPTIONS]", requiresValue:false, defaultValue:nil)
        let option = CliOption(keys:["-o", "--option"], description:"Some Option", usage: nil, requiresValue:false, defaultValue: "default_value")
        let secondaryOption = CliOption(keys:["-a", "--alternate-option"], description:"Alternate Option", usage: nil, requiresValue:false, defaultValue: nil)
        var group = CliOptionGroup(description:"Commands Group:")
        public init(){
            command.add(argument: option)
            command.add(argument: secondaryOption)
            group.options.append(command)
            cliOptionGroups = [group]
        }
        
    }
    
    func testValidateArgumentKeys() {
        do{
            let option = CliOption(keys:[UUID().uuidString.lowercased()], description:"", usage: nil, requiresValue: false, defaultValue: nil)
            
            let result = try option.validateKeys(arguments: option.keys, environment: ["":""])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateArgumentKeys_failure() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", usage: nil, requiresValue: false, defaultValue: nil)
            
            let result = try option.validateKeys(arguments: [""], environment: ["":""])
            
            XCTAssertNil(result)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateEnvironmentKeys() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", usage: nil, requiresValue: false, defaultValue: nil)
            
            let result = try option.validateKeys(arguments:[""], environment: [option.keys.first!:"value"])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateEnvironmentKeys_failure() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", usage: nil, requiresValue: false, defaultValue: nil)
            
            let result = try option.validateKeys(arguments:[""], environment: ["":""])
            
            XCTAssertNil(result)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateKeyWithDefaultValue() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", usage: nil, requiresValue:true, defaultValue:"value")
            
            let result = try option.validateKeys(arguments:[""], environment: ["":""])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testParseOption(){
        do{
            let option = CliOption(keys:[UUID().uuidString.lowercased()], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys, arguments:[option.keys.first!,value], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testParseSecondayOption(){
        do{
            let option = CliOption(keys:["-s", "-secondary"], description:"secondary", usage: nil, requiresValue:true, defaultValue: nil)
            let value = UUID().uuidString
            
            //root -secondary value
            let result = try option.parseValues(using: option.keys, arguments:["root-command", "-secondary", value], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testEnvironmentValues(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys, arguments:[""], environment: [option.keys.first!:value])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testParseDefaultValue(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", usage: nil, requiresValue:true, defaultValue:"defaultValue")
            
            let result = try option.parseValues(using:option.keys, arguments:[""], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, "defaultValue")
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testParseMissingRequiredValue(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            
            let _ = try option.parseValues(using:option.keys, arguments:[""], environment: ["":""])
            
            XCTFail("An error should have been thrown")
            
        } catch _ {
            
        }
    }
    func testParseMutlipleArgumentValues(){
        do{
            let option = CliOption(keys:[UUID().uuidString.lowercased()], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let value1 = UUID().uuidString
            let value2 = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys, arguments:[option.keys.first!,value1,value2], environment: ["":""])
            
            XCTAssertEqual(result.values!, [value1, value2])
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testParseArgumentInListOfArguments() {
        do{
            let preOption = CliOption(keys:["pre-option"], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let option = CliOption(keys:["target-option"], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let postOption = CliOption(keys:["post-option"], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let value1 = UUID().uuidString
            let value2 = UUID().uuidString
            
            let result = try option.parseValues(using:preOption.keys + option.keys + postOption.keys, arguments:[preOption.keys.first!, "preValue", option.keys.first!,value1,value2, postOption.keys.first!, "postValue"], environment: ["":""])
            
            XCTAssertEqual(result.values!, [value1, value2])
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testParseArgumentAtEndListOfArguments() {
        do{
            let preOption = CliOption(keys:["pre-option"], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let option = CliOption(keys:["target-option"], description:"", usage: nil, requiresValue:true, defaultValue: nil)
            let value1 = UUID().uuidString
            let value2 = UUID().uuidString
            
            let result = try option.parseValues(using:preOption.keys + option.keys, arguments:[preOption.keys.first!, "preValue", option.keys.first!,value1,value2], environment: ["":""])
            
            XCTAssertEqual(result.values!, [value1, value2])
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testHelpString(){
        let app = App()
        
        let help = app.helpString(with: app.helpEntries())
        print(help)
        
        XCTAssertTrue(help.contains(app.description!))
        XCTAssertTrue(help.contains(app.group.description))
        XCTAssertTrue(help.contains(app.command.keys.first!))
        XCTAssertTrue(help.contains(app.appUsage!))
    }
    func testDetailedHelpString() {
        let app = App()
        
        let help = app.helpString(with: app.detailedHelpEntries(option: app.command))
        print(help)
        
        XCTAssertTrue(help.contains(app.command.usage!))
        XCTAssertTrue(help.contains(app.command.description))
        XCTAssertTrue(help.contains(app.option.keys.first!))
        XCTAssertTrue(help.contains(app.option.defaultValue!))
        XCTAssertTrue(help.contains(app.secondaryOption.keys.first!))
    }

    //TODO: test if we add the full help feature, otherwise sub options aren't used
/*    func testColumnLength() {
        let app = App()
        let helpEntries = app.detailedHelpEntries(option: app.command)
        
        let length = helpEntries.last?.columnLength()
        
        XCTAssertEqual(length, helpEntries.last.)
    }
    func testStringValue() {
        
    }
 */
    func testParseHelpOption_nil() {
        let app = App()
        let arguments = ["/path/to/app", "command"]
        
        let option = app.parseHelpOption(cliOptionGroups: app.cliOptionGroups, arguments: arguments)
        
        XCTAssertNil(option)
    }
    func testParseHelpOption() {
        let app = App()
        let arguments = ["/path/to/app", app.command.keys.last!, "help"]
        
        let option = app.parseHelpOption(cliOptionGroups: app.cliOptionGroups, arguments: arguments)
        
        XCTAssertEqual(option, app.command)
    }
    func testUnknownKey() {
        let app = App()
        let unknownKey = "--foo-bar"
        let arguments = ["/path/to/app", app.command.keys.last!, "value", unknownKey]
        
        let unknownKeys = app.parseUnknownKeys(arguments: arguments, validKeys: [app.command.keys.last!], values: ["value"])
        
        XCTAssertEqual(unknownKeys, [unknownKey])
    }
    
    static var allTests : [(String, (CliRunnableTests) -> () throws -> Void)] {
        return [
            ("testValidateArgumentKeys", testValidateArgumentKeys),
        ]
    }
}
