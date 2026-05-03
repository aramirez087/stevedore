import Core
import UIMenus
import XCTest

extension PaneCommandProxy {
    static func makeStub(
        currentPath: FilePath = FilePath(scheme: .local, posix: "/tmp"),
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        isRemoteReadOnly: Bool = false,
        goBack: @escaping () -> Void = {},
        goForward: @escaping () -> Void = {},
        goUp: @escaping () -> Void = {},
        goHome: @escaping () -> Void = {},
        goToComputer: @escaping () -> Void = {},
        newFolder: @escaping () -> Void = {},
        newFile: @escaping () -> Void = {},
        open: @escaping () -> Void = {},
        openWith: @escaping () -> Void = {},
        moveToTrash: @escaping () -> Void = {},
        compress: @escaping () -> Void = {},
        decompress: @escaping () -> Void = {},
        toggleHiddenFiles: @escaping () -> Void = {},
        refresh: @escaping () -> Void = {},
        openInTerminal: @escaping () -> Void = {},
        openNewTab: @escaping () -> Void = {},
        closeActiveTab: @escaping () -> Void = {},
        reopenClosedTab: @escaping () -> Void = {},
        nextTab: @escaping () -> Void = {},
        previousTab: @escaping () -> Void = {},
        selectAll: @escaping () -> Void = {},
        sortByName: @escaping () -> Void = {},
        sortByDateModified: @escaping () -> Void = {},
        sortBySize: @escaping () -> Void = {},
        sortByKind: @escaping () -> Void = {}
    ) -> PaneCommandProxy {
        PaneCommandProxy(
            currentPath: currentPath,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            isRemoteReadOnly: isRemoteReadOnly,
            goBack: goBack,
            goForward: goForward,
            goUp: goUp,
            goHome: goHome,
            goToComputer: goToComputer,
            newFolder: newFolder,
            newFile: newFile,
            open: open,
            openWith: openWith,
            moveToTrash: moveToTrash,
            compress: compress,
            decompress: decompress,
            toggleHiddenFiles: toggleHiddenFiles,
            refresh: refresh,
            openInTerminal: openInTerminal,
            openNewTab: openNewTab,
            closeActiveTab: closeActiveTab,
            reopenClosedTab: reopenClosedTab,
            nextTab: nextTab,
            previousTab: previousTab,
            selectAll: selectAll,
            sortByName: sortByName,
            sortByDateModified: sortByDateModified,
            sortBySize: sortBySize,
            sortByKind: sortByKind
        )
    }
}

extension WindowCommandProxy {
    static func makeStub(
        showConnectDialog: @escaping () -> Void = {},
        showSyncDialog: @escaping () -> Void = {},
        showRenameDialog: @escaping () -> Void = {},
        showUninstallerDialog: @escaping () -> Void = {},
        focusSearch: @escaping () -> Void = {}
    ) -> WindowCommandProxy {
        WindowCommandProxy(
            showConnectDialog: showConnectDialog,
            showSyncDialog: showSyncDialog,
            showRenameDialog: showRenameDialog,
            showUninstallerDialog: showUninstallerDialog,
            focusSearch: focusSearch
        )
    }
}
