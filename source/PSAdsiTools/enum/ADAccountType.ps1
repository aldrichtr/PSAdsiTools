
[Flags()]
enum ADAccountType {
    <#
    .SYNOPSIS
        These codes are part of the AD DS Schema for samAccountType
    #>
    DOMAIN           = 0x0
    GROUP            = 0x10000000
    LIST             = 0x10000001
    SEC_ALIAS        = 0x20000000
    ALIAS            = 0x20000001
    USER             = 0x30000000
    MACHINE          = 0x30000001
    TRUST            = 0x30000002
    APP_BASIC_GROUP  = 0x40000000
    APP_QUERY_GROUP  = 0x40000001
    ACCOUNT_TYPE_MAX = 0x7fffffff

}
