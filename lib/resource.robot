*** Settings ***
Library           Collections
Library           String
Library           RequestsLibrary.RequestsKeywords
Library           OperatingSystem
Variables         ../data/variables.py

*** Variables ***

# By default power, support x86 as well.
${PLATFORM_ARCH_TYPE}             power

# Transition REST vs Redfish ONLY temporary changes for stagging
# automation infrastructure change and for continuity.
${REDFISH_SUPPORT_TRANS_STATE}    ${0}

# By default Delete all Redfish session per boot run.
${REDFISH_DELETE_SESSIONS}        ${1}

${OPENBMC_MODEL}  ${EMPTY}
${OPENBMC_HOST}   ${EMPTY}
${DBUS_PREFIX}    ${EMPTY}
${PORT}           ${EMPTY}
# AUTH_SUFFIX here is derived from variables.py
${AUTH_URI}       https://${OPENBMC_HOST}${AUTH_SUFFIX}
${OPENBMC_USERNAME}    root
${OPENBMC_PASSWORD}    0penBmc
${REST_USERNAME}       root
${REST_PASSWORD}       0penBmc

# MTLS_ENABLED indicates whether mTLS is enabled.
${MTLS_ENABLED}        False
# Valid mTLS certificate for authentication.
${VALID_CERT}          ${EMPTY}
# Path of mTLS certificates directory.
${CERT_DIR_PATH}       ${EMPTY}

${IPMI_PASSWORD}       0penBmc
${MACHINE_TYPE}    palmetto
${DBUS_POLL_INTERVAL}      15s
${OPENBMC_REBOOT_TIMEOUT}   ${10}
# IPMI_COMMAND here is set to "External" by default. User
# can override to "Dbus" from command line.
${IPMI_COMMAND}    External
# IPMI chipher default.
${IPMI_CIPHER_LEVEL}  ${17}
# IPMI timeout default.
${IPMI_TIMEOUT}       ${3}

# PDU related parameters
${PDU_TYPE}         ${EMPTY}
${PDU_IP}           ${EMPTY}
${PDU_USERNAME}     ${EMPTY}
${PDU_PASSWORD}     ${EMPTY}
${PDU_SLOT_NO}      ${EMPTY}

# User define input SSH and HTTPS related parameters
${SSH_PORT}         22
${HTTPS_PORT}       443
${IPMI_PORT}        623
${HOST_SOL_PORT}    2200
${OPENBMC_SERIAL_HOST}      ${EMPTY}
${OPENBMC_SERIAL_PORT}      ${EMPTY}

# OS related parameters.
${OS_HOST}          ${EMPTY}
${OS_USERNAME}      ${EMPTY}
${OS_PASSWORD}      ${EMPTY}
${OS_WAIT_TIMEOUT}  ${15*60}

# Networking related parameters
${NETWORK_PORT}            80
${PACKET_TYPE}             tcp
${ICMP_PACKETS}            icmp
${NETWORK_RETRY_TIME}      6
${NETWORK_TIMEOUT}         18
${ICMP_TIMESTAMP_REQUEST}  13
${ICMP_ECHO_REQUEST}       8
${CHANNEL_NUMBER}          1

# BMC debug tarball parameter
${DEBUG_TARBALL_PATH}  ${EMPTY}

# Upload Image parameters
${TFTP_SERVER}                  ${EMPTY}
${PNOR_TFTP_FILE_NAME}          ${EMPTY}
${BMC_TFTP_FILE_NAME}           ${EMPTY}
${IMAGE_FILE_PATH}              ${EMPTY}
${ALTERNATE_IMAGE_FILE_PATH}    ${EMPTY}
${PNOR_IMAGE_FILE_PATH}         ${EMPTY}
${BMC_IMAGE_FILE_PATH}          ${EMPTY}
${BAD_IMAGES_DIR_PATH}          ${EMPTY}
${SKIP_UPDATE_IF_ACTIVE}        false

# Parameters for doing N-1 and N+1 code updates.
${N_MINUS_ONE_IMAGE_FILE_PATH}    ${EMPTY}
${N_PLUS_ONE_IMAGE_FILE_PATH}     ${EMPTY}

# The caller must set this to the string "true" in order to delete images. The
# code is picky.
${DELETE_OLD_PNOR_IMAGES}   false
${DELETE_OLD_GUARD_FILE}    false

# Caller can specify a value for LAST_KNOWN_GOOD_VERSION to indicate that if
# the machine already has that version on it, the update should be skipped.
${LAST_KNOWN_GOOD_VERSION}  ${EMPTY}

# By default field mode is disabled.
${FIELD_MODE}               ${False}

# LDAP related variables.
${LDAP_BASE_DN}             ${EMPTY}
${LDAP_BIND_DN}             ${EMPTY}
${LDAP_SERVER_HOST}         ${EMPTY}
${LDAP_SECURE_MODE}         ${EMPTY}
${LDAP_BIND_DN_PASSWORD}    ${EMPTY}
${LDAP_SEARCH_SCOPE}        ${EMPTY}
${LDAP_TYPE}                ${EMPTY}
${LDAP_USER}                ${EMPTY}
${LDAP_USER_PASSWORD}       ${EMPTY}

*** Keywords ***
Get Inventory Schema
    [Documentation]  Get inventory schema.
    [Arguments]    ${machine}
    [Return]    &{INVENTORY}[${machine}]

Get Inventory Items Schema
    [Documentation]  Get inventory items schema.
    [Arguments]    ${machine}
    [Return]    &{INVENTORY_ITEMS}[${machine}]

Get Sensor Schema
    [Documentation]  Get sensors schema.
    [Arguments]    ${machine}
    [Return]    &{SENSORS}[${machine}]
