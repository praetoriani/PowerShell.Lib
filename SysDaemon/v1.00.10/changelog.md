# 📋 Changelog

All notable changes to SysDaemon will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.00.10] - 2025-10-05 🚫

### ✨ Added
- **Revolutionary Silent Validation**: Complete elimination of PowerShell console error messages
- **Manual Parameter Processing**: Custom `Parse-CommandLineArguments` function for complete control
- **Case Insensitive Parameters**: All parameter names and values now accept any case combination
- **Enhanced Error Messages**: 2+ additional error message types for comprehensive parameter validation
- **Complete $args Processing**: Direct argument array processing bypassing PowerShell parameter binding
- **Zero Console Output**: All parameter validation errors logged silently with no console interference

### 🔧 Changed
- **Removed param() Block**: Eliminated PowerShell's built-in parameter binding completely
- **Manual Argument Parsing**: Implemented custom argument processing using $args array
- **Parameter Validation Logic**: Moved all validation to custom `Parse-CommandLineArguments` function
- **Error Handling Strategy**: Complete silent error handling with comprehensive logging
- **Version Number**: Updated to v1.00.10 to reflect major parameter handling breakthrough

### 🛡️ Security
- **Zero Information Disclosure**: No parameter information leaked through console errors
- **Complete Silent Operation**: All errors handled gracefully without user-visible output
- **Enterprise Security**: Perfect for automation environments requiring silent operation
- **Comprehensive Logging**: All validation errors documented with detailed explanations in log file

### 🐛 Fixed
- **Console Error Elimination**: Completely resolved ALL PowerShell console error message issues
- **Parameter Binding Problems**: Solved PowerShell built-in parameter binding console output
- **Invalid Parameter Handling**: Fixed all scenarios where unknown parameters caused console errors
- **Missing Value Handling**: Resolved console errors when parameters provided without values

### 🔬 Technical Implementation
- **$args Array Processing**: Direct manipulation of PowerShell's $args automatic variable
- **Custom Validation Engine**: Built-in parameter validation with detailed error categorization
- **Language Pack Integration**: Error messages respect user's chosen language pack
- **Fail-Safe Architecture**: Script continues operation even with validation framework failures

### 📖 Documentation
- **Silent Validation Guide**: Comprehensive documentation of new silent parameter validation
- **Troubleshooting Updates**: Updated troubleshooting section with log file analysis examples
- **Technical Architecture**: Documented manual parameter processing implementation
- **Error Analysis**: Provided examples of log file error message formats in multiple languages

## [1.00.09] - 2025-10-05 🔒

### ✨ Added
- **Robust Parameter Validation**: Comprehensive validation of all command-line parameters
- **Silent Error Handling**: All parameter errors are logged silently without console output
- **Enhanced Error Messages**: 8+ new error message types for parameter validation scenarios
- **Security Enhancement**: Prevents information disclosure through console error messages
- **Parameter Restriction**: Only `-axn` and `-LangPack` parameters are now allowed
- **Validation Function**: New `Test-ParameterValidation` function for comprehensive parameter checking

### 🔧 Changed
- **Parameter Processing**: Removed PowerShell built-in validation to enable custom error handling
- **Error Logging**: All parameter validation errors are now logged to `sysdaemon.main.log` instead of console
- **Exit Behavior**: Silent termination with appropriate exit codes for invalid parameters
- **Documentation**: Updated README with comprehensive parameter validation section

### 🛡️ Security
- **Silent Failures**: Invalid parameters cause silent script termination with log-only error reporting
- **Information Protection**: No sensitive parameter information disclosed through console errors
- **Comprehensive Validation**: All parameter combinations and values are thoroughly validated
- **Strict Parameter Control**: Unknown or additional parameters are rejected with detailed logging

### 🐛 Fixed
- **Console Error Messages**: Eliminated PowerShell built-in parameter validation console errors
- **Parameter Validation**: Resolved issues with unknown parameters and invalid parameter values
- **Error Handling**: Fixed console output leakage for parameter validation failures

### 📖 Documentation
- **Parameter Security**: Added comprehensive parameter validation and security section to README
- **Troubleshooting**: Enhanced troubleshooting guide with silent error handling instructions
- **Usage Examples**: Added examples of invalid parameter usage and proper error checking

## [1.00.08] - 2025-10-05 🎯

### ✨ Added
- **Security Enhancement**: Add-job operation now automatically disables tasks after creation for security
- **Multilingual Support**: Dynamic language pack loading message in user's chosen language
- **Code Documentation**: Comprehensive inline documentation for all functions (200+ lines)
- **Function Restructure**: Moved all function documentation inside function bodies for better organization
- **Future Language Support**: Added framework for Italian, French, and Spanish language packs

### 🔧 Changed
- **Code Cleanup**: Removed unused `$originalTaskState` variable from exec-job operation
- **Documentation Format**: Repositioned function comments inside function bodies per PowerShell best practices
- **Enhanced Comments**: Added detailed explanations for critical code sections and security features

### 🐛 Fixed
- **Code Consistency**: Eliminated redundant variable assignments in task execution workflow

## [1.00.07] - 2025-10-05 🔒

### ✨ Added
- **Enhanced Language Pack Handling**: Strict validation with proper fallback mechanisms
- **Exec-Job Security**: Automatic task disabling after successful execution to prevent accidental runs
- **Improved Error Handling**: Better language pack loading error detection and reporting

### 🔧 Changed
- **Language Pack Logic**: Removed hardcoded English fallback, now requires at least en-us.json file
- **Parameter Detection**: Enhanced detection of explicitly provided language pack parameters
- **Security Workflow**: Tasks are now disabled after both creation (add-job) and execution (exec-job)

### 🛡️ Security
- **Fail-Safe Language Loading**: Script terminates if no language pack can be loaded
- **Controlled Task Execution**: Tasks automatically disabled after execution to prevent security risks

## [1.00.06] - 2025-10-05 🚀

### ✨ Added
- **Complete Localization**: All 42+ hardcoded English messages moved to language packs
- **COM-Based Task Manipulation**: Solved PowerShell collection limitation errors
- **Function Renaming**: Updated function names per user requirements
- **Enhanced Error Handling**: Improved error classification (ERROR vs DEBUG levels)

### 🔧 Changed
- **Function Names**: 
  - `Minimize-ConsoleWindow` → `ConsoleWindowToTaskbar`
  - `Replace-TextPlaceholders` → `TextPlaceholdersReplacer`
  - `Replace-MultipleTextPlaceholders` → `MultipleTextPlaceholdersReplacer`
- **Job Script Format**: Updated content format in sysdaemon.job.ps1 (timestamp first, then message)
- **Version Tracking**: Added Creation Date and Last Update fields to file headers

### 🐛 Fixed
- **Collection Size Error**: Resolved "Die Liste hatte eine feste Größe" error using COM objects
- **Trigger Manipulation**: Implemented robust COM-based approach for task trigger modifications
- **Consistent Logging**: All log entries now respect selected language pack

### 🌍 Internationalization
- **Language Packs**: Comprehensive en-us.json and de-de.json with 40+ localized messages
- **UTF-8 BOM Support**: Proper encoding for international characters

## [1.00.05] - 2025-10-04 🛠️

### ✨ Added
- **Multilingual Support**: Introduced JSON-based language packs (en-us.json, de-de.json)
- **Dynamic Version Display**: Version number dynamically inserted into startup messages
- **Enhanced Logging**: Comprehensive logging with multiple severity levels
- **Administrative Validation**: Improved privilege checking and error handling

### 🔧 Changed
- **Configuration Structure**: Externalized all user-facing messages to language pack files
- **Error Messages**: Standardized error message format with detailed logging
- **Startup Sequence**: Enhanced initialization with localized status messages

### 🌍 Internationalization
- **German Language Pack**: Complete German translations for all system messages
- **Language Selection**: Command-line parameter for language pack selection
- **Fallback Mechanism**: Automatic fallback to English if specified language unavailable

## [1.00.04] - 2025-10-04 🔄

### ✨ Added
- **Task Folder Management**: Automatic cleanup of empty task scheduler folders
- **Enhanced Kill-Job**: Improved task termination with historic trigger setting
- **COM Object Integration**: Direct Task Scheduler COM object manipulation

### 🔧 Changed
- **Cleanup Process**: More thorough cleanup after task deletion
- **Error Handling**: Improved error reporting for task operations

### 🐛 Fixed
- **Task Termination**: Resolved issues with task killing and trigger modification
- **Folder Cleanup**: Proper handling of empty task folders after deletion

## [1.00.03] - 2025-10-04 ⚡

### ✨ Added
- **Console Window Management**: Automatic minimization for cleaner user experience
- **Enhanced Task Management**: Improved task creation and deletion workflows
- **Better Error Reporting**: More detailed error messages and logging

### 🔧 Changed
- **Window Behavior**: Tasks now run with minimal console interference
- **Task Configuration**: Enhanced task argument handling and path resolution

## [1.00.02] - 2025-10-04 🔧

### ✨ Added
- **Parameter Validation**: Enhanced input validation for action parameters
- **Task State Checking**: Improved task status verification before operations
- **XML Template Support**: Structured task creation using XML templates

### 🔧 Changed
- **Parameter Handling**: More robust command-line parameter processing
- **Task Operations**: Refined task creation, execution, and deletion logic

### 🐛 Fixed
- **Parameter Case Sensitivity**: Resolved case-sensitive parameter matching issues
- **Task Path Handling**: Fixed path resolution for task arguments

## [1.00.01] - 2025-10-04 🎉

### ✨ Added
- **Basic Task Operations**: Core add-job, del-job, exec-job, kill-job functionality
- **Scheduled Task Integration**: Windows Task Scheduler integration
- **System Context Execution**: Tasks run under SYSTEM user context
- **Logging Infrastructure**: Basic file-based logging system

### 🔧 Changed
- **Core Architecture**: Established fundamental script structure and workflow

## [1.00.00] - 2025-10-04 🌟

### ✨ Added
- **Initial Release**: First version of SysDaemon
- **PowerShell Framework**: Core PowerShell-based daemon infrastructure
- **Command-Line Interface**: Basic parameter-driven task management
- **Windows Integration**: Native Windows Task Scheduler compatibility

### 🎯 Project Goals
- Provide enterprise-grade task scheduling for Windows environments
- Enable system-level automation with security-first design
- Support multilingual deployments for international organizations
- Maintain comprehensive logging and error handling

---

## 🏷️ Version Legend

- 🚫 **Silent Validation Release** - Complete elimination of console error messages with revolutionary parameter processing
- 🔒 **Security Release** - Security improvements, parameter validation, and silent error handling
- 🎯 **Minor Release** - New features and enhancements
- 🚀 **Feature Release** - Important feature additions
- 🛠️ **Maintenance Release** - Bug fixes and improvements
- 🔧 **Patch Release** - Minor fixes and adjustments
- ⚡ **Performance Release** - Performance improvements
- 🔄 **Refactor Release** - Code restructuring and cleanup
- 🎉 **Initial Release** - First version
- 🌟 **Major Release** - Significant new features or breaking changes

## 📞 Support

For issues, feature requests, or contributions, please visit our [GitHub Issues](https://github.com/praetoriani/sysdaemon/issues) page.

---

**SysDaemon Development Team**  
*Committed to reliable system automation since 2025* 🚀