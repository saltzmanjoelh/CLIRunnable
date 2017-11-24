import XCTest
import Yaml
@testable import CliRunnable

class CliRunnableTests: XCTestCase {
    
    let app = App()
    var commandKey = ""
    let commandValue =  UUID().uuidString
    var optionalName = ""
    var optionalValue =  UUID().uuidString
    
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
        commandKey = app.command.keys.first!
        optionalName = app.command.optionalArguments!.first!.keys.first!
    }
    
    struct App : CliRunnable {
        var appName: String = "Test App"
        var description: String? = "My CliRunnable App's description"
        public var appUsage: String? = "app COMMAND [OPTIONS]"
        
        public var cliOptionGroups: [CliOptionGroup]
        
        var command = CliOption(keys:["test-command"], description:"Test a custom command", usage: "app test-command [OPTIONS]", requiresValue:true, defaultValue:nil)
        let option = CliOption(keys:["-o", "--option"], description:"Some Option", usage: nil, requiresValue:false, defaultValue: "default_value")
        let secondaryOption = CliOption(keys:["-a", "--alternate-option"], description:"Alternate Option", usage: nil, requiresValue:false, defaultValue: nil)
        var nextCommand = CliOption(keys:["next-command"], description:"Test a another command", usage: "app next-command [OPTIONS]", requiresValue:false, defaultValue:nil)
        var nextRequiredOption = CliOption(keys:["-r", "--required"], description:"Required Option", usage: nil, requiresValue:true, defaultValue: nil)
        var group = CliOptionGroup(description:"Commands Group:")
        public init(){
            command.add(argument: option)
            command.add(argument: secondaryOption, required: true)
            group.options.append(command)
            group.options.append(nextCommand)
            cliOptionGroups = [group]
        }
        
    }
    func createYamlConfig() -> String {
        let configPath = "/tmp/.config_test"
        //create the yaml file
        let yamlContents = "\(commandKey):\n  \(CommandArgsKey):\n    - \(commandValue)-yaml\n  \(optionalName): \(optionalValue)-yaml"
        try! yamlContents.write(toFile: configPath, atomically: false, encoding: .utf8)
        return configPath
    }
    func cliArgs() -> [String] {
        return [commandKey, commandValue+"-cli", optionalName, optionalValue+"-cli"]
    }
    func environmentArgs() -> [String: String] {
        return [commandKey: "\(commandValue)-env", optionalName: "\(optionalValue)-env"]
    }
    
    func testRangeOfValue() {
        let keys = ["one", "two", "three"]
        let arguments = ["/binary/path"] + keys
        
        let result = app.range(ofKey: "two", inArguments: arguments, withKeys: keys)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.lowerBound, 2)
        XCTAssertEqual(result!.upperBound, 3)
    }
    func testRangeOfValue_multiples() {
        let keys = ["one", "two", "three"]
        let arguments = ["/binary/path", "one", "two", "a", "b", "three"]
        
        let result = app.range(ofKey: "two", inArguments: arguments, withKeys: keys)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.lowerBound, 2)
        XCTAssertEqual(result!.upperBound, 5)
    }
    func testRangeOfValue_endValue() {
        let keys = ["one", "two", "three"]
        let arguments = ["/binary/path", "one", "two", "a", "b"]
        
        let result = app.range(ofKey: "two", inArguments: arguments, withKeys: keys)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.lowerBound, 2)
        XCTAssertEqual(result!.upperBound, 5)
    }
    func testIndexArguments() {
        let arguments = cliArgs()
        let commandKey = arguments[0]
        let commandArg = arguments[1]
        let optionalArgKey = arguments[2]
        let optionalArgValue = arguments[3]
        
        let result = app.index(arguments: arguments, using: app.cliOptionGroups)
        
        XCTAssertNotNil(result[commandKey])
        XCTAssertNotNil(result[commandKey]?[CommandArgsKey])
        XCTAssertEqual(result[commandKey]![CommandArgsKey]!, [commandArg])
        XCTAssertNotNil(result[commandKey]?[optionalArgKey], "\(commandKey) \(optionalArgKey) was missing")
        XCTAssertEqual(result[commandKey]![optionalArgKey]!, [optionalArgValue])
    }
    func testParseYaml() throws {
        let cli = cliArgs()
        let configPath = createYamlConfig()
        let commandKey = cli[0]
        let commandValue =  cli[1].replacingOccurrences(of: "cli", with: "yaml")
        let optionalName = cli[2]
        let optionalValue = cli[3].replacingOccurrences(of: "cli", with: "yaml")
        
        let result = try app.parse(yamlConfigurationPath: configPath)
        
        XCTAssertNotNil(result)
        XCTAssertNotNil(result![commandKey])
        XCTAssertNotNil(result![commandKey]![CommandArgsKey])
        guard let commandArgs = result![commandKey]![CommandArgsKey] else {
            XCTFail("Yaml index didn't contain \"\(CommandArgsKey)\" key. \(result!)")
            return
        }
        XCTAssertEqual(commandArgs, [commandValue])
        XCTAssertNotNil(result![commandKey]![optionalName])
        //make sure that single arg values convert to an array of values to match the cli parsing
        guard let optionalArgs = result![commandKey]![optionalName] else {
            XCTFail("Yaml index should have contained \(optionalName) argument.")
            return
        }
        XCTAssertEqual(optionalArgs, [optionalValue])
    }
    func testParseYaml_emptyFile() throws {
        let configPath = "/tmp/.config_test"
        try? "".write(toFile: configPath, atomically: false, encoding: .utf8)
        
        let result = try app.parse(yamlConfigurationPath: configPath)
        
        XCTAssertNil(result)
    }
    func testParseYaml_nonexistingFile() throws {
        let configPath = ""
        try? "".write(toFile: configPath, atomically: false, encoding: .utf8)
        
        let result = try app.parse(yamlConfigurationPath: configPath)
        
        XCTAssertNil(result)
    }
    func testDecodeEmptyYaml() {
        let yaml = try! [Yaml.load(""): Yaml.load("")]
        
        let result = app.decode(yamlDictionary: yaml)
        
        XCTAssertNil(result)
    }
    
    func testConsolidateArgs_yaml() {
        do {
            let args = [String]()
            let env = [String:String]()
            let configPath = createYamlConfig()
            
            let result = try app.consolidateArgs(arguments: args, environment: env, yamlConfigurationPath: configPath, optionGroups: app.cliOptionGroups)
            
            XCTAssertNotNil(result[commandKey])
            XCTAssertNotNil(result[commandKey]![CommandArgsKey])
            XCTAssertEqual(result[commandKey]![CommandArgsKey]!, [commandValue+"-yaml"])
        }catch let e{
            XCTFail(String(describing: e))
        }
    }
    func testConsolidateArgs_env() {
        do {
            let args = [String]()
            let env = environmentArgs()
            let configPath = createYamlConfig()
            
            let result = try app.consolidateArgs(arguments: args, environment: env, yamlConfigurationPath: configPath, optionGroups: app.cliOptionGroups)
            
            XCTAssertNotNil(result[commandKey])
            XCTAssertNotNil(result[commandKey]![CommandArgsKey])
            XCTAssertEqual(result[commandKey]![CommandArgsKey]!, [commandValue+"-env"])
        }catch let e{
            XCTFail(String(describing: e))
        }
    }
    func testConsolidateArgs_cli() {
        do {
            let args = cliArgs()
            let env = environmentArgs()
            let configPath = createYamlConfig()
            
            let result = try app.consolidateArgs(arguments: args, environment: env, yamlConfigurationPath: configPath, optionGroups: app.cliOptionGroups)
            
            XCTAssertNotNil(result[commandKey])
            XCTAssertNotNil(result[commandKey]![CommandArgsKey])
            XCTAssertEqual(result[commandKey]![CommandArgsKey]!, [commandValue+"-cli"])
        }catch let e{
            XCTFail(String(describing: e))
        }
    }
    func testConsolidateArgs_overEmptyIndexes() {
        do {
            let args = cliArgs()
            
            let result = try app.consolidateArgs(arguments: args, environment: [:], yamlConfigurationPath: "", optionGroups: app.cliOptionGroups)
            
            XCTAssertNotNil(result[commandKey])
            XCTAssertNotNil(result[commandKey]![CommandArgsKey])
            XCTAssertEqual(result[commandKey]![CommandArgsKey]!, [commandValue+"-cli"])
        }catch let e{
            XCTFail(String(describing: e))
        }
    }
    
    func testIndex_missingKeys() {
        let option = CliOption(keys:[], description:"", usage: nil, requiresValue: false, defaultValue: nil)
        
        let result = app.index(option: option, fromArguments: [], withKeys: [])
        
        XCTAssertEqual(result.count, 0)
    }
    func testIndex_command() {
        let app = App()
        let command = app.command
        let allKeys = app.cliOptionGroups.flatMap({ $0.options.flatMap({ $0.allKeys }) })
        let commandValue = "command value"
        let optionValue = UUID().uuidString
        let arguments = ["test-command", commandValue, app.option.keys[0], optionValue]
        
        let result = app.index(option: command,
                               fromArguments: arguments.flatMap({$0.strippingDashPrefix}),
                               withKeys: allKeys.flatMap({$0.strippingDashPrefix}))
        
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[app.command.keys[0]])
        XCTAssertNotNil(result[app.command.keys[0]]?[CommandArgsKey])
        XCTAssertEqual(result[app.command.keys[0]]![CommandArgsKey]?[0], commandValue)
        XCTAssertNotNil(result[app.command.keys[0]]![app.option.keys[0]])
        XCTAssertEqual(result[app.command.keys[0]]![app.option.keys[0]]!, [optionValue])
    }
    func testIndex_commandWithoutOptions() {
        var appWithoutOptions = App()
        var option = app.command
        option.requiredArguments = nil
        option.optionalArguments = nil
        appWithoutOptions.cliOptionGroups = [CliOptionGroup.init(description: "command", options: [option])]
        let allKeys = app.cliOptionGroups.flatMap({ $0.options.flatMap({ $0.allKeys }) })
        let commandValue = "command value"
        let optionValue = UUID().uuidString
        let arguments = ["test-command", commandValue, app.option.keys[0], optionValue]
        
        let result = appWithoutOptions.index(option: app.command, fromArguments: arguments, withKeys: allKeys)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[app.command.keys[0]])
        XCTAssertNotNil(result[app.command.keys[0]]?[CommandArgsKey])
        XCTAssertEqual(result[app.command.keys[0]]![CommandArgsKey]?[0], commandValue)

    }
    
    func testHelpString(){
        
        let help = app.helpString(with: app.helpEntries())
        print(help)
        
        XCTAssertTrue(help.contains(app.description!))
        XCTAssertTrue(help.contains(app.group.description))
        XCTAssertTrue(help.contains(app.command.keys.first!))
        XCTAssertTrue(help.contains(app.appUsage!))
    }
    func testDetailedHelpString() {
        
        let help = app.helpString(with: app.detailedHelpEntries(option: app.command))
        print(help)
        
        XCTAssertTrue(help.contains(app.command.usage!))
        XCTAssertTrue(help.contains(app.command.description))
        XCTAssertTrue(help.contains(app.option.keys.first!))
        XCTAssertTrue(help.contains(app.option.defaultValue!))
        XCTAssertTrue(help.contains(app.secondaryOption.keys.first!))
    }
    
    func testParseHelpOption_nil() {
        let arguments = ["/path/to/app", "command"]
        
        let option = app.parseHelpOption(cliOptionGroups: app.cliOptionGroups, arguments: arguments)
        
        XCTAssertNil(option)
    }
    func testParseHelpOption() {
        let arguments = ["/path/to/app", app.command.keys.last!, "help"]
        
        let option = app.parseHelpOption(cliOptionGroups: app.cliOptionGroups, arguments: arguments)
        
        XCTAssertEqual(option, app.command)
    }
    func testParseHelpOption_invalidOption() {
        let arguments = ["/path/to/app", "invalid", "help"]
        
        let result = app.parseHelpOption(cliOptionGroups: app.cliOptionGroups, arguments: arguments)
        
        XCTAssertNil(result)
    }
    
    func testUnknownKey() {
        let unknownKey = "--foo-bar"
        let arguments = ["/path/to/app", app.command.keys.last!, "value", unknownKey]
        
        let unknownKeys = app.parseUnknownKeys(arguments: arguments, validKeys: [app.command.keys.last!], values: ["value"])
        
        XCTAssertEqual(unknownKeys, [unknownKey])
    }
    func testHandleUnknownKeys() {
        do {
            let unknownKey = "--foo-bar"
            let arguments = ["/path/to/app", app.command.keys.last!, unknownKey]
            
            try app.handleUnknownKeys(arguments: arguments, options: [app.command])
            
            XCTFail("Error should have been thrown.")
        } catch _ {
            
        }
    }
    func testHandleUnknownKeys_validKey() {
        do {
            let arguments = ["/path/to/app", app.command.keys.last!, app.command.optionalArguments![0].keys[0]]
            
            try app.handleUnknownKeys(arguments: arguments, options: [app.command])
            
        } catch let e {
            XCTFail(String(describing: e))
        }
    }
    func testMissingRequiredArguments(){
        do {
            var app = App()
            var cmd = app.command
            let option = CliOption(keys:["-o", "--option"], description:"Some Option", usage: nil, requiresValue:true, defaultValue: nil)
            cmd.requiredArguments = [option]
            app.group.options = [cmd]
            app.cliOptionGroups = [app.group]
            let arguments = ["/path/to/app", "test-command"]
            
            try app.run(arguments: arguments, environment: [:])
            
            XCTFail("Required argument was missing and an error should have been thrown.")
            
        } catch _ {
            //throw an error when a required arg is not provided
        }
    }
    
    func testAppRun_unknownKey() {
        do {
            let app = App()
            let unknownKey = "--foo-bar"
            let arguments = ["/path/to/app", unknownKey]
            
            try app.run(arguments: arguments, environment: [:])
            
        } catch let e {
            XCTAssertEqual(String(describing: e), "Unknown keys: [\"--foo-bar\"]")
        }
    }
    func testAppRun() {
        do {
            let app = App()
            let arguments = ["/path/to/app", "test-command", "value", "-o", "-a"]
            
            try app.run(arguments: arguments, environment: [:])
            
        } catch let e {
            XCTFail("Error: \(e)")
        }
    }
    func testSecondaryKey() {
        do {
            let app = App()
            let arguments = ["/path/to/app", "test-command", "value", "--option", "--alternate-option"]
            
            try app.run(arguments: arguments, environment: [:])
            
        } catch let e {
            XCTFail("Error: \(e)")
        }
    }
    //If we provide a yaml config, we shouldn't use all keys from it. We should only run what was provided in cli args
    func testParseCliArgsWithYaml() {
        do {
            let app = App()
            let yml = "test-command:\n  args: [value]\n  --option: true\nnext-command:\n  --required: true"
            let path = "/tmp/testParseCliArgsWithYaml.yml"
            try! yml.write(to: URL(fileURLWithPath: path), atomically: false, encoding: .utf8)
            let arguments = ["/path/to/app", "test-command", "--alternate-option"]
            
            try app.run(arguments: arguments, environment: [:], yamlConfigurationPath: path)
            
        } catch let e {
            XCTFail("Error: \(e)")
        }
    }
    
    func testStrippingDashPrefix_singleDash() {
        let option = "-option-name"
        
        let result = option.strippingDashPrefix
        
        XCTAssertEqual(result, "option-name")
    }
    func testStrippingDashPrefix_doubleDash() {
        let option = "--option-name"
        
        let result = option.strippingDashPrefix
        
        XCTAssertEqual(result, "option-name")
    }
    func testStrippingDashPrefix_zeroDashes() {
        let option = "option-name"
        
        let result = option.strippingDashPrefix
        
        XCTAssertEqual(result, "option-name")
    }
    
    /*
    func testValidateArgumentKeys() {
        do{
            let option = CliOption(keys:[UUID().uuidString.lowercased()], description:"", usage: nil, requiresValue: false, defaultValue: nil)
            
            let result = try option.validateKeys(indexedArguments: [option.keys.first!: [""]])
            
            XCTAssertEqual(result, option)
            
        } catch let e {
            XCTFail("\(e)")
        }
    }*/
    /*
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
    */
    
    //TODO: test if we add the full help feature, otherwise sub options aren't used
/*    func testColumnLength() {
        let helpEntries = app.detailedHelpEntries(option: app.command)
        
        let length = helpEntries.last?.columnLength()
        
        XCTAssertEqual(length, helpEntries.last.)
    }
    func testStringValue() {
        
    }
 */
    
    
    
    
    
    static var allTests : [(String, (CliRunnableTests) -> () throws -> Void)] {
        return [
            ("testRangeOfValue", testRangeOfValue),
            ("testRangeOfValue_multiples", testRangeOfValue_multiples),
            ("testRangeOfValue_endValue", testRangeOfValue_endValue),
            ("testIndexArguments", testIndexArguments),
            ("testParseYaml", testParseYaml),
            ("testParseYaml_emptyFile", testParseYaml_emptyFile),
            ("testParseYaml_nonexistingFile", testParseYaml_nonexistingFile),
            ("testDecodeEmptyYaml", testDecodeEmptyYaml),
            
            ("testConsolidateArgs_yaml", testConsolidateArgs_yaml),
            ("testConsolidateArgs_env", testConsolidateArgs_env),
            ("testConsolidateArgs_cli", testConsolidateArgs_cli),
            ("testConsolidateArgs_overEmptyIndexes", testConsolidateArgs_overEmptyIndexes),
            
            ("testIndex_missingKeys", testIndex_missingKeys),
            ("testIndex_command", testIndex_command),
            ("testIndex_commandWithoutOptions", testIndex_commandWithoutOptions),
            
            ("testHelpString", testHelpString),
            ("testDetailedHelpString", testDetailedHelpString),
            
            ("testParseHelpOption_nil", testParseHelpOption_nil),
            ("testParseHelpOption", testParseHelpOption),
            ("testParseHelpOption_invalidOption", testParseHelpOption_invalidOption),
            
            ("testUnknownKey", testUnknownKey),
            ("testHandleUnknownKeys", testHandleUnknownKeys),
            ("testHandleUnknownKeys_validKey", testHandleUnknownKeys_validKey),
            ("testMissingRequiredArguments", testMissingRequiredArguments),
            
            ("testAppRun_unknownKey", testAppRun_unknownKey),
            ("testAppRun", testAppRun),
            ("testSecondaryKey", testSecondaryKey),
            ("testParseCliArgsWithYaml", testParseCliArgsWithYaml),
            
            ("testStrippingDashPrefix_singleDash", testStrippingDashPrefix_singleDash),
            ("testStrippingDashPrefix_doubleDash", testStrippingDashPrefix_doubleDash),
            ("testStrippingDashPrefix_zeroDashes", testStrippingDashPrefix_zeroDashes)
            
        ]
    }
}
