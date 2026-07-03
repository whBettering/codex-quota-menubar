import CodexQuotaCore

func testMenuBarClickRoutingSeparatesLeftAndRightClick() throws {
    try expectEqual(
        MenuBarClickRoute.route(isRightClick: false),
        .togglePopover,
        "left click route"
    )
    try expectEqual(
        MenuBarClickRoute.route(isRightClick: true),
        .showContextMenu,
        "right click route"
    )
}
