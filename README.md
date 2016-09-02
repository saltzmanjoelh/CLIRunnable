# CliRunnable
Create and parse command line options for your cli application. Help documentation is auto created for you.

###CliOption

Implement the CliRunnable protocol and provide some CLIOptions.

```
CliOption(keys:["-o", "--option"], description:"Some Option", requiresValue:false)
```

This gives your command line application the ability to add some options when you execute your application.

`app -o` or `app --option`

#####CliOption - requiresValue

You can set the requiresValue property to true or false to specify if the option requires a value or not

`app -o some-value` or `app -o`


#####CliOption - action

Set the action to be performed when the option is triggered 
```
public var action: ((CliOption) throws -> Void)?
```


###CliOption as a Command
You can add sub options in the requiredArguments and optionalArguments arrays to create a command and additional options for the command

```
var command = CliOption(keys:["custom-command"], description:"Custom Command", requiresValue:false)
let option = CliOption(keys:["-o", "--option"], description:"Some Option", requiresValue:false)
command.add(argument: option, required: false)
```

`app custom-command --option`


#####CliOption - optionalArguments, requiredArguments

A command can either have optionalArguments or requiredArguments

```
let secondaryOption = CliOption(keys:["-a", "--alternate-option"], description:"Alternate Option", requiresValue:true)
command.add(argument: option, required: true)
```

`app custom-command --alternate-option my-required-value`


### Printing Help
Help commands are automatically created from the CliOptions and CliOptionGroups

#### Main Application Help
`app help` or `app --help` or `app -h` or no options at all `app`
```
App Description
app COMMAND [OPTIONS]

Custom Commands:
custom-command	Do something custom
```

#### Command Specific Help
`app custom-command help`
```
app custom-command [OPTIONS]

Custom Command
-o, --option          	Some Option
-a, --alternate-option	Alternate Option
```

###CliOptionGroup

You can group options together in a CliOptionGroup if you want to create to group related commands together for the printed help

```
CliOptionGroup(description:"Custom Commands:")
var command = CliOption(keys:["custom-command"], description:"Do something custom", requiresValue:false)
var otherCommand = CliOption(keys:["other-custom-command"], description:"Custom Command", requiresValue:false)
```



### Example CliRunnable struct
```
struct App : CliRunnable {
    var description: String? = "App Description\n"
    let appUsage = "app COMMAND [OPTIONS]\n"
    let customCommandUsage = "app custom-command [OPTIONS]\n"
        
    //prepare your commands and options
    var command = CliOption(keys:["custom-command"], description:"Do something custom", requiresValue:false)
    let option = CliOption(keys:["-o", "--option"], description:"Some Option", requiresValue:false)
    let secondaryOption = CliOption(keys:["-a", "--alternate-option"], description:"Alternate Option", requiresValue:true)
    var group = CliOptionGroup(description:"Commands Group:")
    
    public init(){
        //add your options and to groups
        command.add(argument: option)
        command.add(argument: secondaryOption, required: true)
        group.options.append(command)
        cliOptionGroups = [group]
    }
    
    public var cliOptionGroups: [CliOptionGroup]
    public func usage(option: CliOption?) -> String? {
        return option != nil ? customCommandUsage : appUsage
    }
        
}
```