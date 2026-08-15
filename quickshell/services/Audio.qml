pragma Singleton
pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.functions
import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/**
 * A nice wrapper for default Pipewire audio sink and source.
 * Extended with device aliases (WirePlumber), device cycling, and rich
 * display names — ported from DankMaterialShell's AudioService.
 */
Singleton {
    id: root

    // Misc props
    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource
    readonly property real hardMaxValue: 2.00
    property string audioTheme: Config.options.sounds.theme
    property real value: sink?.audio.volume ?? 0

    // ── Device aliases (WirePlumber config) ──────────────────────────────
    property var deviceAliases: ({})
    readonly property string wireplumberConfigPath: {
        const configBase = FileUtils.trimFileProtocol(Directories.config)
        return configBase + "/wireplumber/wireplumber.conf.d/51-sumika-audio-aliases.conf"
    }
    property bool wireplumberReloading: false

    // ── Typed device lists (kept in sync with Pipewire) ──────────────────
    property list<var> typedSinks: []
    property list<var> typedSources: []
    property var savedLevels: ({})
    readonly property string levelsStatePath: FileUtils.trimFileProtocol(Directories.state) + "/audio-levels.json"

    // ── Signals ──────────────────────────────────────────────────────────
    signal sinkProtectionTriggered(string reason)
    signal micMuteChanged()
    signal audioOutputCycled(string deviceName, string deviceIcon)
    signal deviceAliasChanged(string nodeName, string newAlias)
    signal wireplumberReloadStarted()
    signal wireplumberReloadCompleted(bool success)

    Component.onCompleted: {
        rebuildTypedNodeLists()
        loadDeviceAliases()
        loadDeviceLevels()
        refreshCardProfiles()
    }

    // ── Display name resolution ──────────────────────────────────────────
    function displayName(node) {
        if (!node) return ""
        // 1. Custom alias from our map
        if (node.name && deviceAliases[node.name]) {
            return deviceAliases[node.name]
        }
        // 2. WirePlumber-applied node.description
        if (node.properties && node.properties["node.description"]) {
            const desc = node.properties["node.description"]
            if (desc !== node.name) return desc
        }
        // 3. Cached description
        if (node.description && node.description !== node.name) {
            return node.description
        }
        // 4. device.description
        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"]
        }
        // 5. nickname
        if (node.nickname && node.nickname !== node.name) {
            return node.nickname
        }
        // 6. Pattern-based friendly names
        if (node.name && node.name.includes("analog-stereo")) return "Built-in Audio Analog Stereo"
        if (node.name && node.name.includes("bluez")) return "Bluetooth Audio"
        if (node.name && node.name.includes("usb")) return "USB Audio"
        if (node.name && node.name.includes("hdmi")) return "HDMI Audio"
        return node.name ?? "Unknown"
    }

    function originalName(node) {
        if (!node) return ""
        if (node.name && node.name.includes("analog-stereo")) return "Built-in Audio Analog Stereo"
        if (node.name && node.name.includes("bluez")) return "Bluetooth Audio"
        if (node.name && node.name.includes("usb")) return "USB Audio"
        if (node.name && node.name.includes("hdmi")) return "HDMI Audio"
        if (node.properties && node.properties["device.description"]) return node.properties["device.description"]
        if (node.nickname && node.nickname !== node.name) return node.nickname
        return node.name ?? "Unknown"
    }

    function sinkIcon(node) {
        if (!node) return "speaker"
        const name = (node.name || "").toLowerCase()
        const desc = (displayName(node) || "").toLowerCase()
        if (name.includes("bluez") || desc.includes("headset") || desc.includes("airpods")) return "headset"
        if (name.includes("hdmi") || desc.includes("tv")) return "tv"
        if (desc.includes("speaker")) return "speaker"
        return "speaker"
    }

    function friendlyDeviceName(node) {
        return displayName(node)
    }
    function appNodeDisplayName(node) {
        return (node.properties["application.name"] || node.description || node.name)
    }

    // ── Typed node list management ───────────────────────────────────────
    function rebuildTypedNodeLists() {
        const newSinks = []
        const newSources = []
        for (const node of Pipewire.nodes.values) {
            if (!node?.audio || node.isStream) continue
            if (node.isSink) newSinks.push(node)
            else newSources.push(node)
        }
        typedSinks = newSinks
        typedSources = newSources
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            root.rebuildTypedNodeLists()
            // Profile switches recreate nodes; re-read card profiles.
            cardProfileRefreshTimer.restart()
        }
    }

    // ── Card profiles (ALSA profile switching / recovery) ───────────────
    // Profiles are not exposed via the Quickshell Pipewire API, so they are
    // read from `pactl -f json list cards`. pactl emits profiles either as
    // an object map (name -> info) or as an array; both are handled.
    property var cardProfiles: []

    readonly property var switchableCards: {
        const out = []
        for (const card of root.cardProfiles) {
            // Skip "off" (disables the card) and unavailable profiles;
            // cards left with fewer than two options need no switcher.
            const list = card.profiles.filter(p => p.name !== "off" && p.available)
            if (list.length >= 2)
                out.push({
                    name: card.name,
                    description: card.description,
                    activeProfile: card.activeProfile,
                    profiles: list
                })
        }
        return out
    }

    function refreshCardProfiles() {
        if (cardProfileReadProc.running)
            return
        cardProfileReadProc.running = true
    }

    function parseCardProfiles(text) {
        if (!text || text.trim() === "")
            return []
        let cards
        try {
            cards = JSON.parse(text)
        } catch (e) {
            return []
        }
        if (!Array.isArray(cards))
            return []
        const out = []
        for (const card of cards) {
            if (!card || typeof card.name !== "string" || card.name.length === 0)
                continue
            const raw = card.profiles
            if (!raw || typeof raw !== "object")
                continue
            const entries = Array.isArray(raw)
                ? raw.map(p => [p?.name, p])
                : Object.keys(raw).map(key => [key, raw[key]])
            const profiles = []
            for (const [name, info] of entries) {
                if (typeof name !== "string" || name.length === 0)
                    continue
                profiles.push({
                    name: name,
                    description: info?.description ?? "",
                    priority: info?.priority ?? 0,
                    available: info?.available !== false
                })
            }
            profiles.sort((a, b) => (b.priority - a.priority) || a.name.localeCompare(b.name))
            out.push({
                name: card.name,
                description: card?.properties?.["device.description"] ?? card.name,
                activeProfile: typeof card.active_profile === "string" ? card.active_profile : "",
                profiles: profiles
            })
        }
        return out
    }

    function setCardProfile(cardName, profileName) {
        if (!cardName || !profileName)
            return false
        cardProfileSetProc.command = ["pactl", "set-card-profile", cardName, profileName]
        cardProfileSetProc.running = true
        return true
    }

    function friendlyProfileName(profileName) {
        if (!profileName)
            return ""
        if (profileName === "pro-audio")
            return "Pro Audio (raw)"
        const match = profileName.match(/^HiFi\s*\((.+)\)$/)
        if (!match)
            return profileName
        const labels = {
            "Headphones": "Headphones",
            "Speaker": "Speakers",
            "Mic1": "Mic 1",
            "Mic2": "Mic 2"
        }
        const tokens = match[1].split(",").map(t => labels[t.trim()] ?? t.trim())
        return "HiFi · " + tokens.join(", ")
    }

    Process {
        id: cardProfileReadProc
        running: false
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            id: cardProfileCollector
            onStreamFinished: root.cardProfiles = root.parseCardProfiles(cardProfileCollector.text)
        }
    }

    Process {
        id: cardProfileSetProc
        running: false
        onExited: (exitCode, exitStatus) => cardProfileRefreshTimer.restart()
    }

    Timer {
        id: cardProfileRefreshTimer
        interval: 600
        repeat: false
        onTriggered: root.refreshCardProfiles()
    }

    // ── Device selection ─────────────────────────────────────────────────
    function nodeObjectId(node) {
        if (!node)
            return "";
        // Quickshell PwNode.id is the PipeWire object id used by wpctl.
        const id = node.id;
        if (id !== undefined && id !== null && id !== "")
            return id.toString();
        const serial = node.properties?.["object.serial"];
        if (serial !== undefined && serial !== null && serial !== "")
            return serial.toString();
        return "";
    }

    function setDefaultSink(node) {
        if (!node)
            return false;
        Pipewire.preferredDefaultAudioSink = node;
        const id = nodeObjectId(node);
        if (id.length)
            Quickshell.execDetached(["wpctl", "set-default", id]);
        // Fallback: some sessions honor pactl name better than a stale id.
        if (node.name)
            Quickshell.execDetached(["pactl", "set-default-sink", node.name]);
        return true;
    }

    function setDefaultSource(node) {
        if (!node)
            return false;
        Pipewire.preferredDefaultAudioSource = node;
        const id = nodeObjectId(node);
        if (id.length)
            Quickshell.execDetached(["wpctl", "set-default", id]);
        if (node.name)
            Quickshell.execDetached(["pactl", "set-default-source", node.name]);
        return true;
    }

    function setDefaultSinkByName(name) {
        if (!name) return false
        for (const node of typedSinks) {
            if (node?.name === name) return setDefaultSink(node)
        }
        return false
    }

    function setDefaultSourceByName(name) {
        if (!name) return false
        for (const node of typedSources) {
            if (node?.name === name) return setDefaultSource(node)
        }
        return false
    }

    function cycleAudioOutput() {
        const sinks = typedSinks
        if (sinks.length < 2) return null
        const currentName = root.sink?.name ?? ""
        const currentIndex = sinks.findIndex(s => s.name === currentName)
        const nextIndex = ((currentIndex + 1) % sinks.length + sinks.length) % sinks.length
        const nextSink = sinks[nextIndex]
        setDefaultSinkByName(nextSink.name)
        const name = displayName(nextSink)
        audioOutputCycled(name, sinkIcon(nextSink))
        return name
    }

    // ── Device aliases (WirePlumber config) ──────────────────────────────
    function getDeviceAlias(nodeName) {
        if (!nodeName) return null
        return deviceAliases[nodeName] || null
    }

    function hasDeviceAlias(nodeName) {
        if (!nodeName) return false
        return Object.prototype.hasOwnProperty.call(deviceAliases, nodeName)
            && deviceAliases[nodeName] !== null
            && deviceAliases[nodeName] !== ""
    }

    function setDeviceAlias(nodeName, customAlias) {
        if (!nodeName) return false
        if (!customAlias || customAlias.trim() === "") {
            return removeDeviceAlias(nodeName)
        }
        const trimmed = customAlias.trim()
        const updated = Object.assign({}, deviceAliases)
        updated[nodeName] = trimmed
        deviceAliases = updated
        writeWireplumberConfig()
        deviceAliasChanged(nodeName, trimmed)
        return true
    }

    function removeDeviceAlias(nodeName) {
        if (!nodeName || !hasDeviceAlias(nodeName)) return false
        const updated = Object.assign({}, deviceAliases)
        delete updated[nodeName]
        deviceAliases = updated
        writeWireplumberConfig()
        deviceAliasChanged(nodeName, "")
        return true
    }

    function generateWireplumberConfig() {
        // User aliases are free text; escape backslashes and double quotes
        // so one odd character can't corrupt the generated config.
        const esc = (s) => String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
        let config = "# Generated by Sumika Shell - Audio Device Aliases\n"
        config += "# Do not edit manually - changes will be overwritten\n\n"
        const aliasKeys = Object.keys(deviceAliases)
        if (aliasKeys.length === 0) return config

        const alsaAliases = []
        const bluezAliases = []
        const otherAliases = []
        for (const nodeName of aliasKeys) {
            const alias = deviceAliases[nodeName]
            if (!alias) continue
            if (nodeName.includes("alsa")) alsaAliases.push({nodeName, alias})
            else if (nodeName.includes("bluez")) bluezAliases.push({nodeName, alias})
            else otherAliases.push({nodeName, alias})
        }

        if (alsaAliases.length > 0) {
            config += "monitor.alsa.rules = [\n"
            alsaAliases.forEach((rule, i) => {
                config += "  {\n"
                config += `    matches = [ { "node.name" = "${esc(rule.nodeName)}" } ]\n`
                config += `    actions = { update-props = { "node.description" = "${esc(rule.alias)}" } }\n`
                config += "  }"
                if (i < alsaAliases.length - 1) config += ","
                config += "\n"
            })
            config += "]\n\n"
        }
        if (bluezAliases.length > 0) {
            config += "monitor.bluez.rules = [\n"
            bluezAliases.forEach((rule, i) => {
                config += "  {\n"
                config += `    matches = [ { "node.name" = "${esc(rule.nodeName)}" } ]\n`
                config += `    actions = { update-props = { "node.description" = "${esc(rule.alias)}" } }\n`
                config += "  }"
                if (i < bluezAliases.length - 1) config += ","
                config += "\n"
            })
            config += "]\n\n"
        }
        if (otherAliases.length > 0) {
            config += "wireplumber.rules = [\n"
            otherAliases.forEach((rule, i) => {
                config += "  {\n"
                config += `    matches = [ { "node.name" = "${esc(rule.nodeName)}" } ]\n`
                config += `    actions = { update-props = { "node.description" = "${esc(rule.alias)}" } }\n`
                config += "  }"
                if (i < otherAliases.length - 1) config += ","
                config += "\n"
            })
            config += "]\n"
        }
        return config
    }

    function writeWireplumberConfig() {
        const configDir = FileUtils.trimFileProtocol(Directories.config) + "/wireplumber/wireplumber.conf.d"
        const configContent = generateWireplumberConfig()
        const shellCmd = `mkdir -p "${configDir}" && cat > "${wireplumberConfigPath}" << 'EOFCONFIG'\n${configContent}\nEOFCONFIG\n`
        wpWriteProc.command = ["sh", "-c", shellCmd]
        wpWriteProc.running = true
    }

    Process {
        id: wpWriteProc
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                reloadWireplumberConfig()
            }
        }
    }

    function reloadWireplumberConfig() {
        if (wireplumberReloading) return
        wireplumberReloading = true
        wireplumberReloadStarted()
        wpReloadProc.running = true
    }

    Process {
        id: wpReloadProc
        command: ["systemctl", "--user", "restart", "wireplumber"]
        running: false
        onExited: (exitCode, exitStatus) => {
            wireplumberReloading = false
            wireplumberReloadCompleted(exitCode === 0)
        }
    }

    function loadDeviceAliases() {
        wpReadProc.running = true
    }

    Process {
        id: wpReadProc
        command: ["cat", wireplumberConfigPath]
        running: false
        stdout: StdioCollector {
            id: wpReadCollector
            onStreamFinished: {
                const output = wpReadCollector.text
                if (!output || output.trim() === "") return
                const aliases = {}
                let currentNodeName = null
                for (const line of output.split('\n')) {
                    const nameMatch = line.match(/"node\.name"\s*=\s*"([^"]+)"/)
                    if (nameMatch) currentNodeName = nameMatch[1]
                    const descMatch = line.match(/"node\.description"\s*=\s*"([^"]+)"/)
                    if (descMatch && currentNodeName) {
                        aliases[currentNodeName] = descMatch[1]
                        currentNodeName = null
                    }
                }
                if (Object.keys(aliases).length > 0) {
                    deviceAliases = aliases
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Exit code non-zero = no config file yet, which is fine
        }
    }

    // ── Lists ────────────────────────────────────────────────────────────
    function correctType(node, isSink) {
        return (node.isSink === isSink) && node.audio
    }
    function appNodes(isSink) {
        return Pipewire.nodes.values.filter((node) => {
            return root.correctType(node, isSink) && node.isStream
        })
    }
    function devices(isSink) {
        return Pipewire.nodes.values.filter(node => {
            return root.correctType(node, isSink) && !node.isStream
        })
    }
    readonly property list<var> outputAppNodes: root.appNodes(true)
    readonly property list<var> inputAppNodes: root.appNodes(false)
    readonly property list<var> outputDevices: root.devices(true)
    readonly property list<var> inputDevices: root.devices(false)

    // ── Volume persistence (state/audio-levels.json) ──────────────────────
    property bool restoringLevel: false

    function scheduleLevelSave() {
        if (root.restoringLevel)
            return
        levelSaveTimer.restart()
    }

    function writeDeviceLevels() {
        const levels = Object.assign({}, root.savedLevels || {})
        if (root.sink?.name && root.sink?.audio) {
            levels[root.sink.name] = {
                volume: root.sink.audio.volume,
                muted: root.sink.audio.muted,
            }
        }
        if (root.source?.name && root.source?.audio) {
            levels[root.source.name] = {
                volume: root.source.audio.volume,
                muted: root.source.audio.muted,
            }
        }
        root.savedLevels = levels
        const stateDir = root.levelsStatePath.replace(/\/[^/]*$/, "")
        const payload = JSON.stringify(levels).replace(/'/g, "'\\''")
        levelWriteProc.command = ["sh", "-c", `mkdir -p '${stateDir}' && printf '%s' '${payload}' > '${root.levelsStatePath}'`]
        levelWriteProc.running = true
    }

    function restoreNodeLevel(node) {
        if (!node?.name || !node?.audio)
            return
        const saved = root.savedLevels?.[node.name]
        if (!saved)
            return
        root.restoringLevel = true
        if (saved.volume !== undefined && saved.volume !== null)
            node.audio.volume = Math.max(0, Math.min(1, saved.volume))
        if (saved.muted !== undefined && saved.muted !== null)
            node.audio.muted = saved.muted
        root.restoringLevel = false
    }

    function loadDeviceLevels() {
        levelReadProc.running = true
    }

    Process {
        id: levelReadProc
        command: ["cat", root.levelsStatePath]
        running: false
        stdout: StdioCollector {
            id: levelReadCollector
            onStreamFinished: {
                const text = levelReadCollector.text
                if (!text || text.trim() === "")
                    return
                try {
                    const parsed = JSON.parse(text)
                    root.savedLevels = parsed && typeof parsed === "object" ? parsed : ({})
                    if (root.sink)
                        root.restoreNodeLevel(root.sink)
                    if (root.source)
                        root.restoreNodeLevel(root.source)
                } catch (e) {
                    root.savedLevels = ({})
                }
            }
        }
    }

    Process {
        id: levelWriteProc
        running: false
    }

    function setSinkVolume(value) {
        if (!sink?.audio)
            return
        const clamped = Math.max(0, Math.min(1, value))
        sink.audio.volume = clamped
        if (sink.audio.muted && clamped > 0)
            sink.audio.muted = false
        root.scheduleLevelSave()
    }

    function setSourceVolume(value) {
        if (!source?.audio)
            return
        const clamped = Math.max(0, Math.min(1, value))
        source.audio.volume = clamped
        if (source.audio.muted && clamped > 0)
            source.audio.muted = false
        root.scheduleLevelSave()
    }

    // ── Controls ─────────────────────────────────────────────────────────
    function toggleMute() {
        if (sink?.audio) {
            sink.audio.muted = !sink.audio.muted
            root.scheduleLevelSave()
        }
    }

    function toggleMicMute() {
        if (source?.audio) {
            source.audio.muted = !source.audio.muted
            micMuteChanged()
            root.scheduleLevelSave()
        }
    }

    function incrementVolume() {
        const currentVolume = root.value
        const step = currentVolume < 0.1 ? 0.01 : 0.02
        if (sink?.audio) {
            const newVolume = Math.min(1, sink.audio.volume + step)
            sink.audio.volume = newVolume
            if (sink.audio.muted && newVolume > 0)
                sink.audio.muted = false
            root.scheduleLevelSave()
        }
    }

    function decrementVolume() {
        const currentVolume = root.value
        const step = currentVolume < 0.1 ? 0.01 : 0.02
        if (sink?.audio) {
            const newVolume = Math.max(0, sink.audio.volume - step)
            sink.audio.volume = newVolume
            if (sink.audio.muted && newVolume > 0)
                sink.audio.muted = false
            root.scheduleLevelSave()
        }
    }

    Timer {
        id: levelSaveTimer
        interval: 250
        repeat: false
        onTriggered: root.writeDeviceLevels()
    }

    Connections {
        target: root
        function onReadyChanged() {
            if (!root.ready)
                return
            if (root.sink)
                root.restoreNodeLevel(root.sink)
            if (root.source)
                root.restoreNodeLevel(root.source)
        }
        function onSinkChanged() {
            // Node replaced (profile switch / device change): the volume
            // protection baseline must restart from the new node, or its
            // first volume event looks like an "Illegal increment" jump
            // from the dead node's lastVolume.
            sinkProtection.lastReady = false
            sinkProtection.lastVolume = 0
            if (root.sink)
                Qt.callLater(() => root.restoreNodeLevel(root.sink))
        }
        function onSourceChanged() {
            if (root.source)
                Qt.callLater(() => root.restoreNodeLevel(root.source))
        }
    }

    // ── Internals ────────────────────────────────────────────────────────
    PwObjectTracker {
        objects: [sink, source]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() {
            root.scheduleLevelSave()
        }
        function onMutedChanged() {
            root.scheduleLevelSave()
        }
    }

    Connections {
        target: root.source?.audio ?? null
        function onVolumeChanged() {
            root.scheduleLevelSave()
        }
        function onMutedChanged() {
            root.scheduleLevelSave()
        }
    }

    Connections {
        id: sinkProtection
        target: sink?.audio ?? null
        property bool lastReady: false
        property real lastVolume: 0
        function onVolumeChanged() {
            if (!Config.options.audio.protection.enable) return
            const newVolume = sink.audio.volume
            if (isNaN(newVolume) || newVolume === undefined || newVolume === null) {
                lastReady = false
                lastVolume = 0
                return
            }
            if (!lastReady) {
                lastVolume = newVolume
                lastReady = true
                return
            }
            const maxAllowedIncrease = Config.options.audio.protection.maxAllowedIncrease / 100
            const maxAllowed = Config.options.audio.protection.maxAllowed / 100
            if (newVolume - lastVolume > maxAllowedIncrease) {
                sink.audio.volume = lastVolume
                root.sinkProtectionTriggered("Illegal increment")
            } else if (newVolume > maxAllowed || newVolume > root.hardMaxValue) {
                root.sinkProtectionTriggered("Exceeded max allowed")
                sink.audio.volume = Math.min(lastVolume, maxAllowed)
            }
            lastVolume = sink.audio.volume
        }
    }

    function playSystemSound(soundName) {
        const ogaPath = `/usr/share/sounds/${root.audioTheme}/stereo/${soundName}.oga`
        const oggPath = `/usr/share/sounds/${root.audioTheme}/stereo/${soundName}.ogg`
        Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", ogaPath])
        Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", oggPath])
    }
}
