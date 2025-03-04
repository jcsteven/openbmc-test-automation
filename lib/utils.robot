*** Settings ***

Documentation  Utilities for Robot keywords that use REST.

Resource                ../lib/resource.robot
Resource                ../lib/rest_client.robot
Resource                ../lib/connection_client.robot
Resource                ../lib/boot_utils.robot
Resource                ../lib/common_utils.robot
Library                 String
Library                 DateTime
Library                 Process
Library                 OperatingSystem
Library                 gen_print.py
Library                 gen_misc.py
Library                 gen_robot_print.py
Library                 gen_cmd.py
Library                 gen_robot_keyword.py
Library                 bmc_ssh_utils.py
Library                 utils.py
Library                 var_funcs.py
Library                 SCPLibrary  WITH NAME  scp
Library                 gen_robot_valid.py


*** Variables ***

${SYSTEM_SHUTDOWN_TIME}   ${5}

# Assign default value to QUIET for programs which may not define it.
${QUIET}  ${0}

${HOST_SETTING}    ${SETTINGS_URI}host0

${boot_prog_method}               ${EMPTY}
${power_policy_setup}             ${0}
${bmc_power_policy_method}        ${EMPTY}


*** Keywords ***


Verify Ping and REST Authentication
    [Documentation]  Verify ping and rest authentication.
    ${l_ping}=   Run Keyword And Return Status
    ...    Ping Host  ${OPENBMC_HOST}
    Run Keyword If  '${l_ping}' == '${False}'
    ...    Fail   msg=Ping Failed

    ${l_rest}=   Run Keyword And Return Status
    ...    Initialize OpenBMC
    Run Keyword If  '${l_rest}' == '${False}'
    ...    Fail   msg=REST Authentication Failed

    # Just to make sure the SSH is working for SCP
    Open Connection And Log In
    ${system}   ${stderr}=    Execute Command   hostname   return_stderr=True
    Should Be Empty     ${stderr}


Check If BMC is Up
    [Documentation]  Wait for Host to be online. Checks every X seconds
    ...              interval for Y minutes and fails if timed out.
    ...              Default MAX timedout is 10 min, interval 10 seconds.
    [Arguments]      ${max_timeout}=${OPENBMC_REBOOT_TIMEOUT} min
    ...              ${interval}=10 sec

    # Description of argument(s):
    # max_timeout   Maximum time to wait.
    #               This should be expressed in Robot Framework's time format
    #               (e.g. "10 minutes").
    # interval      Interval to wait between status checks.
    #               This should be expressed in Robot Framework's time format
    #               (e.g. "5 seconds").

    Wait Until Keyword Succeeds
    ...   ${max_timeout}  ${interval}   Verify Ping and REST Authentication


Flush REST Sessions
    [Documentation]   Removes all the active session objects
    Delete All Sessions


Trigger Host Watchdog Error
    [Documentation]  Inject host watchdog timeout error via REST.
    [Arguments]  ${milliseconds}=1000  ${sleep_time}=5s

    # Description of argument(s):
    # milliseconds  The time watchdog timer value in milliseconds (e.g. 1000 =
    #               1 second).
    # sleep_time    Time delay for host watchdog error to get injected.
    #               Default is 5 seconds.

    ${data}=  Create Dictionary
    ...  data=xyz.openbmc_project.State.Watchdog.Action.PowerCycle
    ${status}  ${result}=  Run Keyword And Ignore Error
    ...  Read Attribute  ${HOST_WATCHDOG_URI}  ExpireAction
    Run Keyword If  '${status}' == 'PASS'
    ...  Write Attribute  ${HOST_WATCHDOG_URI}  ExpireAction  data=${data}

    ${int_milliseconds}=  Convert To Integer  ${milliseconds}
    ${data}=  Create Dictionary  data=${int_milliseconds}
    Write Attribute  ${HOST_WATCHDOG_URI}  Interval  data=${data}

    ${data}=  Create Dictionary  data=${True}
    Write Attribute  ${HOST_WATCHDOG_URI}  Enabled  data=${data}

    Sleep  ${sleep_time}


Login To OS Host
    [Documentation]  Login to OS Host and return the Login response code.
    [Arguments]  ${os_host}=${OS_HOST}  ${os_username}=${OS_USERNAME}
    ...          ${os_password}=${OS_PASSWORD}

    # Description of arguments:
    # ${os_host} IP address of the OS Host.
    # ${os_username}  OS Host Login user name.
    # ${os_password}  OS Host Login passwrd.

    REST Power On  stack_mode=skip  quiet=1

    SSHLibrary.Open Connection  ${os_host}
    ${resp}=  SSHLibrary.Login  ${os_username}  ${os_password}
    [Return]  ${resp}


Initiate Auto Reboot
    [Documentation]  Initiate an auto reboot.
    [Arguments]  ${milliseconds}=5000

    # Description of argument(s):
    # milliseconds  The number of milliseconds for the watchdog timer.

    # Set the auto reboot policy.
    Set Auto Reboot  ${1}
    # Set the watchdog timer.
    Trigger Host Watchdog Error  ${milliseconds}


Initiate OS Host Reboot
    [Documentation]  Initiate an OS reboot.
    [Arguments]  ${os_host}=${OS_HOST}  ${os_username}=${OS_USERNAME}
    ...          ${os_password}=${OS_PASSWORD}

    # Description of argument(s):
    # os_host      The host name or IP address of the OS.
    # os_username  The username to be used to sign in to the OS.
    # os_password  The password to be used to sign in to the OS.

    ${cmd_buf}=  Run Keyword If  '${os_username}' == 'root'
    ...      Set Variable  reboot
    ...  ELSE
    ...      Set Variable  echo ${os_password} | sudo -S reboot

    ${output}  ${stderr}  ${rc}=  OS Execute Command
    ...  ${cmd_buf}  fork=${1}


Initiate OS Host Power Off
    [Documentation]  Initiate an OS reboot.
    [Arguments]  ${os_host}=${OS_HOST}  ${os_username}=${OS_USERNAME}
    ...          ${os_password}=${OS_PASSWORD}  ${hard}=${0}

    # Description of argument(s):
    # os_host      The DNS name or IP of the OS.
    # os_username  The username to be used to sign in to the OS.
    # os_password  The password to be used to sign in to the OS.
    # hard         Indicates whether to do a hard vs. soft power off.

    ${time_string}=  Run Keyword If  ${hard}  Set Variable  ${SPACE}now
    ...  ELSE  Set Variable  ${EMPTY}

    ${cmd_buf}=  Run Keyword If  '${os_username}' == 'root'
    ...      Set Variable  shutdown${time_string}
    ...  ELSE
    ...      Set Variable  echo ${os_password} | sudo -S shutdown${time_string}

    ${output}  ${stderr}  ${rc}=  OS Execute Command
    ...  ${cmd_buf}  fork=${1}


Set System LED State
    [Documentation]  Set given system LED via REST.
    [Arguments]  ${led_name}  ${led_state}
    # Description of argument(s):
    # led_name     System LED name (e.g. heartbeat, identify, beep).
    # led_state    LED state to be set (e.g. On, Off).

    ${args}=  Create Dictionary
    ...  data=xyz.openbmc_project.Led.Physical.Action.${led_state}
    Write Attribute  ${LED_PHYSICAL_URI}${led_name}  State  data=${args}

    Verify LED State  ${led_name}  ${led_state}


Read Turbo Setting Via REST
    [Documentation]  Return turbo setting via REST.
    # Returns 1 if TurboAllowed, 0 if not.

    ${turbo_setting}=  Read Attribute
    ...  ${CONTROL_HOST_URI}turbo_allowed  TurboAllowed
    [Return]  ${turbo_setting}


Set Turbo Setting Via REST
    [Documentation]  Set turbo setting via REST.
    [Arguments]  ${setting}  ${verify}=${False}

    # Description of argument(s):
    # setting  State to set TurboAllowed, 1=allowed, 0=not allowed.
    # verify   If True, read the TurboAllowed setting to confirm.

    ${data}=  Create Dictionary  data=${${setting}}
    Write Attribute  ${CONTROL_HOST_URI}turbo_allowed  TurboAllowed
    ...  verify=${verify}  data=${data}


Set REST Logging Policy
    [Documentation]  Enable or disable REST logging setting.
    [Arguments]  ${policy_setting}=${True}

    # Description of argument(s):
    # policy_setting    The policy setting value which can be either
    #                   True or False.

    ${log_dict}=  Create Dictionary  data=${policy_setting}
    Write Attribute  ${BMC_LOGGING_URI}rest_api_logs  Enabled
    ...  data=${log_dict}  verify=${1}  expected_value=${policy_setting}


Old Get Boot Progress
    [Documentation]  Get the boot progress the old way (via org location).
    [Arguments]  ${quiet}=${QUIET}

    # Description of argument(s):
    # quiet   Indicates whether this keyword should run without any output to
    #         the console.

    ${state}=  Read Attribute  ${OPENBMC_BASE_URI}sensors/host/BootProgress
    ...  value  quiet=${quiet}

    [Return]  ${state}


Set Boot Progress Method
    [Documentation]  Set the boot_prog_method to either 'Old' or 'New'.

    # The boot progress data has moved from an 'org' location to an 'xyz'
    # location.  This keyword will determine whether the new method of getting
    # the boot progress is valid and will set the global boot_prog_method
    # variable accordingly.  If boot_prog_method is already set (either by a
    # prior call to this function or via a -v parm), this keyword will simply
    # return.

    # Note:  There are interim builds that contain boot_progress in both the
    # old and the new location values.  It is nearly impossible for this
    # keyword to determine whether the old boot_progress or the new one is
    # active.  When using such builds where the old boot_progress is active,
    # the only recourse users will have is that they may specify
    # -v boot_prog_method:Old to force old behavior on such builds.

    Run Keyword If  '${boot_prog_method}' != '${EMPTY}'  Return From Keyword

    ${new_status}  ${new_value}=  Run Keyword And Ignore Error
    ...  New Get Boot Progress
    # If the new style read fails, the method must necessarily be "Old".
    Run Keyword If  '${new_status}' == 'PASS'
    ...  Run Keywords
    ...  Set Global Variable  ${boot_prog_method}  New  AND
    ...  Rqpvars  boot_prog_method  AND
    ...  Return From Keyword

    # Default method is "Old".
    Set Global Variable  ${boot_prog_method}  Old
    Rqpvars  boot_prog_method


Initiate Power On
    [Documentation]  Initiates the power on and waits until the Is Power On
    ...  keyword returns that the power state has switched to on.
    [Arguments]  ${wait}=${1}

    # Description of argument(s):
    # wait   Indicates whether to wait for a powered on state after issuing
    #        the power on command.

    @{arglist}=   Create List
    ${args}=     Create Dictionary    data=@{arglist}
    ${resp}=  Call Method  ${OPENBMC_BASE_URI}control/chassis0/  powerOn
    ...  data=${args}
    should be equal as strings      ${resp.status_code}     ${HTTP_OK}

    # Does caller want to wait for power on status?
    Run Keyword If  '${wait}' == '${0}'  Return From Keyword
    Wait Until Keyword Succeeds  3 min  10 sec  Is Power On


Initiate Power Off
    [Documentation]  Initiates the power off and waits until the Is Power Off
    ...  keyword returns that the power state has switched to off.

    @{arglist}=   Create List
    ${args}=     Create Dictionary    data=@{arglist}
    ${resp}=  Call Method  ${OPENBMC_BASE_URI}control/chassis0/  powerOff
    ...  data=${args}
    should be equal as strings      ${resp.status_code}     ${HTTP_OK}
    Wait Until Keyword Succeeds  1 min  10 sec  Is Power Off


Get Boot Progress
    [Documentation]  Get the boot progress and return it.
    [Arguments]  ${quiet}=${QUIET}

    # Description of argument(s):
    # quiet   Indicates whether this keyword should run without any output to
    #         the console.

    Set Boot Progress Method
    ${state}=  Run Keyword If  '${boot_prog_method}' == 'New'
    ...      New Get Boot Progress  quiet=${quiet}
    ...  ELSE
    ...      Old Get Boot Progress  quiet=${quiet}

    [Return]  ${state}


New Get Boot Progress
    [Documentation]  Get the boot progress the new way (via xyz location).
    [Arguments]  ${quiet}=${QUIET}

    # Description of argument(s):
    # quiet   Indicates whether this keyword should run without any output to
    #         the console.

    ${state}=  Read Attribute  ${HOST_STATE_URI}  BootProgress  quiet=${quiet}

    [Return]  ${state.rsplit('.', 1)[1]}


New Get Power Policy
    [Documentation]  Returns the BMC power policy (new method).
    ${currentPolicy}=  Read Attribute  ${POWER_RESTORE_URI}  PowerRestorePolicy

    [Return]  ${currentPolicy}


Old Get Power Policy
    [Documentation]  Returns the BMC power policy (old method).
    ${currentPolicy}=  Read Attribute  ${HOST_SETTING}  power_policy

    [Return]  ${currentPolicy}


Redfish Get Power Restore Policy
    [Documentation]  Returns the BMC power restore policy.

    ${power_restore_policy}=  Redfish.Get Attribute  /redfish/v1/Systems/system  PowerRestorePolicy
    [Return]  ${power_restore_policy}


Get Auto Reboot
    [Documentation]  Returns auto reboot setting.
    ${setting}=  Read Attribute  ${CONTROL_HOST_URI}/auto_reboot  AutoReboot

    [Return]  ${setting}


Redfish Get Auto Reboot
    [Documentation]  Returns auto reboot setting.

    ${resp}=  Redfish.Get Attribute  /redfish/v1/Systems/system  Boot
    [Return]  ${resp["AutomaticRetryConfig"]}


Trigger Warm Reset
    [Documentation]  Initiate a warm reset.

    log to console    "Triggering warm reset"
    ${data}=   create dictionary   data=@{EMPTY}
    ${resp}=  openbmc post request
    ...  ${OPENBMC_BASE_URI}control/bmc0/action/warmReset  data=${data}
    Should Be Equal As Strings      ${resp.status_code}     ${HTTP_OK}
    ${session_active}=   Check If warmReset is Initiated
    Run Keyword If   '${session_active}' == '${True}'
    ...    Fail   msg=warm reset didn't occur

    Sleep   ${SYSTEM_SHUTDOWN_TIME}min
    Check If BMC Is Up


Get Power State
    [Documentation]  Returns the power state as an integer. Either 0 or 1.
    [Arguments]  ${quiet}=${QUIET}

    # Description of argument(s):
    # quiet   Indicates whether this keyword should run without any output to
    #         the console.

    @{arglist}=  Create List
    ${args}=  Create Dictionary  data=@{arglist}

    ${resp}=  Call Method  ${OPENBMC_BASE_URI}control/chassis0/  getPowerState
    ...        data=${args}  quiet=${quiet}
    Should be equal as strings  ${resp.status_code}  ${HTTP_OK}
    ${content}=  to json  ${resp.content}

    [Return]  ${content["data"]}


Clear BMC Gard Record
    [Documentation]  Clear gard records from the system.

    @{arglist}=  Create List
    ${args}=  Create Dictionary  data=@{arglist}
    ${resp}=  Call Method
    ...  ${OPENPOWER_CONTROL}gard  Reset  data=${args}
    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}


Flash PNOR
    [Documentation]    Calls flash bios update method to flash PNOR image
    [Arguments]    ${pnor_image}

    # Description of argument(s):
    # pnor_image  The filename and path of the PNOR image
    #             (e.g. "/home/image/zaius.pnor").

    @{arglist}=   Create List    ${pnor_image}
    ${args}=     Create Dictionary    data=@{arglist}
    ${resp}=  Call Method  /org/openbmc/control/flash/bios/  update
    ...  data=${args}
    should be equal as strings      ${resp.status_code}     ${HTTP_OK}
    Wait Until Keyword Succeeds    2 min   10 sec    Is PNOR Flashing


Get Flash BIOS Status
    [Documentation]  Returns the status of the flash BIOS API as a string. For
    ...              example 'Flashing', 'Flash Done', etc
    ${data}=  Read Properties  /org/openbmc/control/flash/bios
    [Return]    ${data['status']}


Is PNOR Flashing
    [Documentation]  Get BIOS 'Flashing' status. This indicates that PNOR
    ...              flashing has started.
    ${status}=    Get Flash BIOS Status
    Should Contain  ${status}  Flashing


Is PNOR Flash Done
    [Documentation]  Get BIOS 'Flash Done' status.  This indicates that the
    ...              PNOR flashing has completed.
    ${status}=    Get Flash BIOS Status
    should be equal as strings     ${status}     Flash Done


Create OS Console File Path
    [Documentation]  Create OS console file path name and return it.
    [Arguments]  ${log_file_path}=${EMPTY}

    # Description of arguments:
    # file_path  The caller's candidate value.  If this value is ${EMPTY}, this
    #            keyword will compose a file path name.  Otherwise, this
    #            keyword will use the caller's file_path value.  In either
    #            case, the value will be returned.

    ${status}=  Run Keyword And Return Status  Variable Should Exist
    ...  ${TEST_NAME}

    ${default_file_path}=  Set Variable If  ${status} == ${TRUE}
    ...  /tmp/${OPENBMC_HOST}_${TEST_NAME.replace(' ', '')}_os_console.txt
    ...  /tmp/${OPENBMC_HOST}_os_console.txt

    ${log_file_path}=  Set Variable If  '${log_file_path}' == '${EMPTY}'
    ...  ${default_file_path}  ${log_file_path}

    [Return]  ${log_file_path}


Get Endpoint Paths
    [Documentation]   Returns all url paths ending with given endpoint
    ...               Example:
    ...               Given the following endpoint: cpu
    ...               This keyword will return: list of all urls ending with
    ...               cpu -
    ...               /org/openbmc/inventory/system/chassis/motherboard/cpu0,
    ...               /org/openbmc/inventory/system/chassis/motherboard/cpu1
    [Arguments]   ${path}   ${endpoint}

    # Description of arguments:
    # path       URL path for enumeration.
    # endpoint   Endpoint string (url path ending).

    # Make sure path ends with slash.
    ${path}=  Add Trailing Slash  ${path}

    ${resp}=  Read Properties  ${path}enumerate  timeout=30
    Log Dictionary  ${resp}

    ${list}=  Get Dictionary Keys  ${resp}
    # For a given string, look for prefix and suffix for matching expression.
    # Start of string followed by zero or more of any character followed by
    # any digit or lower case character.
    ${resp}=  Get Matches  ${list}  regexp=^.*[0-9a-z_].${endpoint}\[_0-9a-z]*$  case_insensitive=${True}

    [Return]  ${resp}


Set BMC Power Policy
    [Documentation]   Set the given BMC power policy.
    [Arguments]   ${policy}

    # Note that this function will translate the old style "RESTORE_LAST_STATE"
    # policy to the new style "xyz.openbmc_project.Control.Power.RestorePolicy.
    # Policy.Restore" for you.

    # Description of argument(s):
    # policy    Power restore policy (e.g "RESTORE_LAST_STATE",
    #           ${RESTORE_LAST_STATE}).

    # Set the bmc_power_policy_method to either 'Old' or 'New'.
    Set Power Policy Method
    # This translation helps bridge between old and new method for calling.
    ${policy}=  Translate Power Policy Value  ${policy}
    # Run the appropriate keyword.
    Run Key  ${bmc_power_policy_method} Set Power Policy \ ${policy}
    ${currentPolicy}=  Get System Power Policy
    Should Be Equal    ${currentPolicy}   ${policy}


Delete Error Logs
    [Documentation]  Delete error logs.
    [Arguments]  ${quiet}=${0}
    # Description of argument(s):
    # quiet    If enabled, turns off logging to console.

    # Check if error logs entries exist, if not return.
    ${resp}=  OpenBMC Get Request  ${BMC_LOGGING_ENTRY}list  quiet=${1}
    Return From Keyword If  ${resp.status_code} == ${HTTP_NOT_FOUND}

    # Get the list of error logs entries and delete them all.
    ${elog_entries}=  Get URL List  ${BMC_LOGGING_ENTRY}
    FOR  ${entry}  IN  @{elog_entries}
        Delete Error Log Entry  ${entry}  quiet=${quiet}
    END


Delete All Error Logs
    [Documentation]  Delete all error log entries using "DeleteAll" interface.

    ${data}=  Create Dictionary  data=@{EMPTY}
    ${resp}=  Openbmc Post Request  ${BMC_LOGGING_URI}action/DeleteAll
    ...  data=${data}
    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}


Get Elog URL List
    [Documentation]  Return error log entry list of URLs.

    ${url_list}=  Read Properties  /xyz/openbmc_project/logging/entry/
    Sort List  ${url_list}
    [Return]  ${url_list}


Get BMC Flash Chip Boot Side
    [Documentation]  Return the BMC flash chip boot side.

    # Example:
    # 0  - indicates chip select is current side.
    # 32 - indicates chip select is alternate side.

    ${boot_side}  ${stderr}  ${rc}=  BMC Execute Command
    ...  cat /sys/class/watchdog/watchdog1/bootstatus

    [Return]  ${boot_side}


Watchdog Object Should Exist
    [Documentation]  Check that watchdog object exists.

    ${resp}=  OpenBMC Get Request  ${WATCHDOG_URI}host0
    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}
    ...  msg=Expected watchdog object does not exist.


Get System LED State
    [Documentation]  Return the state of given system LED.
    [Arguments]  ${led_name}

    # Description of argument(s):
    # led_name     System LED name (e.g. heartbeat, identify, beep).

    ${state}=  Read Attribute  ${LED_PHYSICAL_URI}${led_name}  State
    [Return]  ${state.rsplit('.', 1)[1]}


Verify LED State
    [Documentation]  Checks if LED is in given state.
    [Arguments]  ${led_name}  ${led_state}
    # Description of argument(s):
    # led_name     System LED name (e.g. heartbeat, identify, beep).
    # led_state    LED state to be verified (e.g. On, Off).

    ${state}=  Get System LED State  ${led_name}
    Should Be Equal  ${state}  ${led_state}


Get LED State XYZ
    [Documentation]  Returns state of given LED.
    [Arguments]  ${led_name}

    # Description of argument(s):
    # led_name  Name of LED.

    ${state}=  Read Attribute  ${LED_GROUPS_URI}${led_name}  Asserted
    # Returns the state of the LED, either On or Off.
    [Return]  ${state}


Verify Identify LED State
    [Documentation]  Verify that the identify state of the LED group matches caller's expectations.
    [Arguments]  ${expected_state}

    # Description of argument(s):
    # expected_state  The expected LED asserted state (1 = asserted, 0 = not asserted).

    ${led_state}=  Get LED State XYZ  enclosure_identify
    Should Be Equal  ${led_state}  ${expected_state}  msg=Unexpected LED state.

Verify The Attribute
    [Documentation]  Verify the given attribute.
    [Arguments]  ${uri}  ${attribute_name}  ${attribute_value}

    # Description of argument(s):
    # uri              URI path
    #                  (e.g. "/xyz/openbmc_project/control/host0/TPMEnable").
    # attribute_name   Name of attribute to be verified (e.g. "TPMEnable").
    # attribute_value  The expected value of attribute (e.g. "1", "0", etc.)

    ${output}=  Read Attribute  ${uri}  ${attribute_name}
    Should Be Equal  ${attribute_value}  ${output}
    ...  msg=Attribute "${attribute_name} does not have the expected value.


New Set Power Policy
    [Documentation]   Set the given BMC power policy (new method).
    [Arguments]   ${policy}

    # Description of argument(s):
    # policy    Power restore policy (e.g. ${ALWAYS_POWER_OFF}).

    ${valueDict}=  Create Dictionary  data=${policy}
    Write Attribute
    ...  ${POWER_RESTORE_URI}  PowerRestorePolicy  data=${valueDict}


Old Set Power Policy
    [Documentation]   Set the given BMC power policy (old method).
    [Arguments]   ${policy}

    # Description of argument(s):
    # policy    Power restore policy (e.g. "ALWAYS_POWER_OFF").

    ${valueDict}=     create dictionary  data=${policy}
    Write Attribute    ${HOST_SETTING}    power_policy   data=${valueDict}


Redfish Set Power Restore Policy
    [Documentation]   Set the BMC power restore policy.
    [Arguments]   ${power_restore_policy}

    # Description of argument(s):
    # power_restore_policy    Power restore policy (e.g. "AlwaysOff", "AlwaysOn", "LastState").

    Redfish.Patch  /redfish/v1/Systems/system  body={"PowerRestorePolicy": "${power_restore_policy}"}
    ...  valid_status_codes=[${HTTP_OK}, ${HTTP_NO_CONTENT}]


Set Auto Reboot Setting
    [Documentation]  Set the given auto reboot setting (REST or Redfish).
    [Arguments]  ${value}

    # Description of argument(s):
    # value    The reboot setting, 1 for enabling and 0 for disabling.

    # This is to cater to boot call points and plugin script which will always
    # send using value 0 or 1. This dictionary maps to redfish string values.
    ${rest_redfish_dict}=  Create Dictionary
    ...                    1=RetryAttempts
    ...                    0=Disabled

    Run Keyword If  ${REDFISH_SUPPORT_TRANS_STATE} == ${1}
    ...    Redfish Set Auto Reboot  ${rest_redfish_dict["${value}"]}
    ...  ELSE
    ...    Set Auto Reboot  ${value}

Set Auto Reboot
    [Documentation]  Set the given auto reboot setting.
    [Arguments]  ${setting}

    # Description of argument(s):
    # setting    The reboot setting, 1 for enabling and 0 for disabling.

    ${valueDict}=  Convert To Integer  ${setting}
    ${data}=  Create Dictionary  data=${valueDict}
    Write Attribute  ${CONTROL_HOST_URI}/auto_reboot  AutoReboot   data=${data}
    ${current_setting}=  Get Auto Reboot
    Should Be Equal As Integers  ${current_setting}  ${setting}


Redfish Set Auto Reboot
    [Documentation]  Set the given auto reboot setting.
    [Arguments]  ${setting}

    # Description of argument(s):
    # setting    The reboot setting, "RetryAttempts" and "Disabled".

    Redfish.Patch  /redfish/v1/Systems/system  body={"Boot": {"AutomaticRetryConfig": "${setting}"}}
    ...  valid_status_codes=[${HTTP_OK}, ${HTTP_NO_CONTENT}]

    ${current_setting}=  Redfish Get Auto Reboot
    Should Be Equal As Strings  ${current_setting}  ${setting}


Set Control Boot Mode
    [Documentation]  Set given boot mode on the boot object path attribute.
    [Arguments]  ${boot_path}  ${boot_mode}

    # Description of argument(s):
    # boot_path  Boot object path.
    #            Example:
    #            /xyz/openbmc_project/control/host0/boot
    #            /xyz/openbmc_project/control/host0/boot/one_time
    # boot_mode  Boot mode which need to be set.
    #            Example:
    #            "xyz.openbmc_project.Control.Boot.Mode.Modes.Regular"

    ${valueDict}=  Create Dictionary  data=${boot_mode}
    Write Attribute  ${boot_path}  BootMode  data=${valueDict}


Is Power On
    [Documentation]  Verify that the BMC chassis state is on.
    ${state}=  Get Power State
    Should be equal  ${state}  ${1}


Is Power Off
    [Documentation]  Verify that the BMC chassis state is off.
    ${state}=  Get Power State
    Should be equal  ${state}  ${0}


CLI Get BMC DateTime
    [Documentation]  Returns BMC date time from date command.

    ${bmc_time_via_date}  ${stderr}  ${rc}=  BMC Execute Command  date +"%Y-%m-%d %H:%M:%S"  print_err=1
    [Return]  ${bmc_time_via_date}


Update Root Password
    [Documentation]  Update system "root" user password.
    [Arguments]  ${openbmc_password}=${OPENBMC_PASSWORD}

    # Description of argument(s):
    # openbmc_password   The root password for the open BMC system.

    @{password}=  Create List  ${openbmc_password}
    ${data}=  Create Dictionary  data=@{password}

    ${headers}=  Create Dictionary  Content-Type=application/json  X-Auth-Token=${XAUTH_TOKEN}
    ${resp}=  Post Request  openbmc  ${BMC_USER_URI}root/action/SetPassword
    ...  data=${data}  headers=${headers}
    Valid Value  resp.status_code  [${HTTP_OK}]


Get Post Boot Action
    [Documentation]  Get post boot action.

    # Post code update action dictionary.
    #
    # {
    #    BMC image: {
    #        OnReset: Redfish OBMC Reboot (off),
    #        Immediate: Wait For Reboot  start_boot_seconds=${state['epoch_seconds']}
    #    },
    #    Host image: {
    #        OnReset: RF SYS GracefulRestart,
    #        Immediate: Wait State  os_running_match_state  10 mins
    #    }
    # }

    ${code_base_dir_path}=  Get Code Base Dir Path
    ${post_code_update_actions}=  Evaluate
    ...  json.load(open('${code_base_dir_path}data/applytime_table.json'))  modules=json
    Rprint Vars  post_code_update_actions

    [Return]  ${post_code_update_actions}


Redfish Set Boot Default
    [Documentation]  Set and Verify BootSource and BootType.
    [Arguments]      ${override_enabled}  ${override_target}

    # Description of argument(s):
    # override_enabled    Boot source enable type.
    #                     ('Once', 'Continuous', 'Disabled').
    # override_target     Boot target type.
    #                     ('Pxe', 'Cd', 'Hdd', 'Diags', 'BiosSetup', 'None').

    ${data}=  Create Dictionary  BootSourceOverrideEnabled=${override_enabled}
    ...  BootSourceOverrideTarget=${override_target}
    ${payload}=  Create Dictionary  Boot=${data}

    Redfish.Patch  /redfish/v1/Systems/system  body=&{payload}
    ...  valid_status_codes=[${HTTP_OK},${HTTP_NO_CONTENT}]

    ${resp}=  Redfish.Get Attribute  /redfish/v1/Systems/system  Boot
    Should Be Equal As Strings  ${resp["BootSourceOverrideEnabled"]}  ${override_enabled}
    Should Be Equal As Strings  ${resp["BootSourceOverrideTarget"]}  ${override_target}


# Redfish state keywords.

Redfish Get BMC State
    [Documentation]  Return BMC health state.

    # "Enabled" ->  BMC Ready, "Starting" -> BMC NotReady

    # Example:
    # "Status": {
    #    "Health": "OK",
    #    "HealthRollup": "OK",
    #    "State": "Enabled"
    # },

    ${status}=  Redfish.Get Attribute  /redfish/v1/Managers/bmc  Status
    [Return]  ${status["State"]}


Redfish Get Host State
    [Documentation]  Return host power and health state.

    # Refer: http://redfish.dmtf.org/schemas/v1/Resource.json#/definitions/Status

    # Example:
    # "PowerState": "Off",
    # "Status": {
    #    "Health": "OK",
    #    "HealthRollup": "OK",
    #    "State": "StandbyOffline"
    # },

    ${chassis}=  Redfish.Get Properties  /redfish/v1/Chassis/chassis
    [Return]  ${chassis["PowerState"]}  ${chassis["Status"]["State"]}


Redfish Get Boot Progress
    [Documentation]  Return boot progress state.

    # Example: /redfish/v1/Systems/system/
    # "BootProgress": {
    #    "LastState": "OSRunning"
    # },

    ${boot_progress}=  Redfish.Get Properties  /redfish/v1/Systems/system/
    [Return]  ${boot_progress["BootProgress"]["LastState"]}  ${boot_progress["Status"]["State"]}


Redfish Get States
    [Documentation]  Return all the BMC and host states in dictionary.
    [Timeout]  30 Seconds

    # Refer: openbmc/docs/designs/boot-progress.md

    Redfish.Login

    ${bmc_state}=  Redfish Get BMC State
    ${chassis_state}  ${chassis_status}=  Redfish Get Host State
    ${boot_progress}  ${host_state}=  Redfish Get Boot Progress

    ${states}=  Create Dictionary
    ...  bmc=${bmc_state}
    ...  chassis=${chassis_state}
    ...  host=${host_state}
    ...  boot_progress=${boot_progress}

    # Disable loggoing state to prevent huge log.html record when boot
    # test is run in loops.
    #Log  ${states}

    [Return]  ${states}


Is BMC Standby
    [Documentation]  Check if BMC is ready and host at standby.

    ${standby_states}=  Create Dictionary
    ...  bmc=Enabled
    ...  chassis=Off
    ...  host=Disabled
    ...  boot_progress=None

    Wait Until Keyword Succeeds  3 min  10 sec  Redfish Get States

    Wait Until Keyword Succeeds  1 min  10 sec  Match State  ${standby_states}


Match State
    [Documentation]  Check if the expected and current states are matched.
    [Arguments]  ${match_state}

    # Description of argument(s):
    # match_state      Expected states in dictionary.

    ${current_state}=  Redfish Get States
    Dictionaries Should Be Equal  ${match_state}  ${current_state}
