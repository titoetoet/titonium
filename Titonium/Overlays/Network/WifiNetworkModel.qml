pragma ComponentBehavior: Bound

import QtQuick

// Reconcile value snapshots by network identity so metadata updates and sorting
// retain the row's transient password editor, cursor and keyboard focus.
ListModel {
    id: root

    property var networks: []
    dynamicRoles: true

    onNetworksChanged: root.reconcile()
    Component.onCompleted: root.reconcile()

    function reconcile(): void {
        const source = root.networks || [];
        for (let index = 0; index < source.length; index += 1) {
            const network = source[index];
            let existing = index;
            while (existing < root.count && root.get(existing).networkId !== network.id)
                existing += 1;
            if (existing === root.count) {
                root.insert(index, { networkId: network.id, descriptor: network });
            } else {
                if (existing !== index)
                    root.move(existing, index, 1);
                root.setProperty(index, "descriptor", network);
            }
        }
        if (root.count > source.length)
            root.remove(source.length, root.count - source.length);
    }
}
