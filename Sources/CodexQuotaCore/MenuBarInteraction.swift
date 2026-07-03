public enum MenuBarClickRoute: Equatable {
    case togglePopover
    case showContextMenu

    public static func route(isRightClick: Bool) -> Self {
        isRightClick ? .showContextMenu : .togglePopover
    }
}
