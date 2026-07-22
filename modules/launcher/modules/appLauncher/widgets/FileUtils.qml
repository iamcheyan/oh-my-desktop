pragma Singleton
import QtQuick

QtObject {
    function trimFileProtocol(str) {
        let s = str;
        if (typeof s !== "string") s = str.toString();
        return s.startsWith("file://") ? s.slice(7) : s;
    }
}
