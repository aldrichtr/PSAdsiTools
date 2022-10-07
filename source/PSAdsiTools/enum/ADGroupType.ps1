
[Flags()]
enum ADGroupType {
    System    = 0x0000001
    Global    = 0x0000002
    Local     = 0x0000004
    Universal = 0x0000008
    APP_BASIC = 0x00000010
    APP_QUERY = 0x00000020
    Security  = 0x80000000 # 2147483648 # If this flag is not set, then the group is a distribution group.
}
