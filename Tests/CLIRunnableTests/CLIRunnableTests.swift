import XCTest
@testable import CliRunnable

class CliRunnableTests: XCTestCase {
    
    
    
    struct App : CliRunnable {
        var description: String? = "App Description\n"
        public let appUsage = "app COMMAND [OPTIONS]\n"
        public let testCommandUsage = "app test-command [OPTIONS]\n"
        
        public var cliOptionGroups: [CliOptionGroup]
        public func usage(option: CliOption?) -> String? {
            return option != nil ? testCommandUsage : appUsage
        }
        
        var command = CliOption(keys:["test-command"], description:"Test Command", requiresValue:false)
        let option = CliOption(keys:["-o", "--option"], description:"Some Option", requiresValue:false)
        let secondaryOption = CliOption(keys:["-a", "--alternate-option"], description:"Alternate Option", requiresValue:false)
        var group = CliOptionGroup(description:"Commands Group:")
        public init(){
            description = "App Description"
            command.add(argument: option)
            command.add(argument: secondaryOption)
            group.options.append(command)
            cliOptionGroups = [group]
        }
        
    }
    
    func testValidateArgumentKeys() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"")
            
            let result = try option.validateKeys(arguments: option.keys, environment: ["":""])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateArgumentKeys_failure() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"")
            
            let result = try option.validateKeys(arguments: [""], environment: ["":""])
            
            XCTAssertNil(result)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateEnvironmentKeys() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"")
            
            let result = try option.validateKeys(arguments:[""], environment: [option.keys.first!:"value"])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testValidateEnvironmentKeys_failure() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"")
            
            let result = try option.validateKeys(arguments:[""], environment: ["":""])
            
            XCTAssertNil(result)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testDefaultKey() {
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            
            let result = try option.validateKeys(arguments:[""], environment: ["":""])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testParseRootValue(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys, arguments:[option.keys.first!,value], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testParseRootValueWithSecondayOption(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let secondaryOption = CliOption(keys:[UUID().uuidString], description:"", requiresValue:false, defaultValue:"secondary")
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys+secondaryOption.keys, arguments:[option.keys.first!,value], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testEnvironmentValues(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let value = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys, arguments:[""], environment: [option.keys.first!:value])
            
            XCTAssertEqual(result.values?.first, value)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testParseDefaultValue(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"defaultValue")
            
            let result = try option.parseValues(using:option.keys, arguments:[""], environment: ["":""])
            
            XCTAssertEqual(result.values?.first, "defaultValue")
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testParseMissingRequiredValue(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", requiresValue:true)
            
            let _ = try option.parseValues(using:option.keys, arguments:[""], environment: ["":""])
            
            XCTFail("An error should have been thrown")
            
        } catch _ {
            
        }
    }
    func testParseMutlipleValues(){
        do{
            let option = CliOption(keys:[UUID().uuidString], description:"", requiresValue:true, defaultValue:"value")
            let secondaryOption = CliOption(keys:[UUID().uuidString], description:"", requiresValue:false, defaultValue:"secondary")
            let value1 = UUID().uuidString
            let value2 = UUID().uuidString
            
            let result = try option.parseValues(using:option.keys+secondaryOption.keys, arguments:[option.keys.first!,value1,value2], environment: ["":""])
            
            XCTAssertEqual(result.values!, [value1, value2])
            
        } catch let e {
            XCTFail("\(e)")
        }
    }
    func testHelpString(){
        let app = App()
        
        let help = app.helpString(with: app.helpEntries())
        
        XCTAssertTrue(help.contains(app.description!))
        XCTAssertTrue(help.contains(app.group.description))
        XCTAssertTrue(help.contains(app.command.keys.first!))
        XCTAssertTrue(help.contains(app.appUsage))
    }
    func testDetailedHelpString() {
        let app = App()
        
        let help = app.helpString(with: app.detailedHelpEntries(option: app.command))
        
        XCTAssertTrue(help.contains(app.testCommandUsage))
        XCTAssertTrue(help.contains(app.command.description))
        XCTAssertTrue(help.contains(app.option.keys.first!))
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
        let arguments = ["/path/to/app", "app"]
        
        let option = app.parseHelpOption(cliOptionGroups: app.cliOptionGroups, arguments: arguments)
        
        XCTAssertNil(option)
    }
    func testParseHelpOption() {
        let app = App()
        let arguments = ["/path/to/app", "app", app.command.keys.last!, "help"]
        
        let option = app.parseHelpOption(cliOptionGroups: app.cliOptionGroups, arguments: arguments)
        
        XCTAssertEqual(option, app.command)
    }
    
    static var allTests : [(String, (CliRunnableTests) -> () throws -> Void)] {
        return [
            ("testValidateArgumentKeys", testValidateArgumentKeys),
        ]
    }
}
