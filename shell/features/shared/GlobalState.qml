pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell.Singleton supports child objects such as FileView. QtObject does not.
Singleton {
    id: state

    property bool isControlPanelOpen: false
    property string configError: ""

    readonly property var defaults: ({
        version: 1,
        bar: {
            height: 60,
            margin: 10,
            layout: {
                left: ["systemInfo", "activeWindow"],
                center: ["workspaces", "clock"],
                right: ["systray", "controlPanelToggle"]
            }
        },
        geometry: { width: 356, height: 520, marginTop: 5, marginRight: 12 },
        appearance: {
            skin: "bloodsteel",
            colorScheme: "crimson",
            animations: "balanced",
            motionScale: 1.0,
            ornaments: true,
            glow: true
        },
        // Optional overrides are used only with skin: "custom". Presets stay switchable.
        theme: { customColors: {} },
        // Legacy-compatible control-panel order. Existing user configs remain valid.
        layout: ["Wifi", "Bluetooth", "Volume", "Mic", "Appearance"],
        modules: {
            Wifi: { showIcon: true, showSsid: true },
            Bluetooth: { showIcon: true },
            Volume: { showPercentage: true, step: 1, maxVolume: 100 },
            Mic: { showPercentage: true, step: 1, maxVolume: 100 },
            Appearance: {},
            Clock: { format: "ddd DD MMM HH:mm", fontSize: 13 },
            Workspaces: { count: 10, romanNumerals: true, animationDuration: 250 },
            ActiveWindow: { maxWidth: 250 },
            SystemInfo: { showCpu: true, showMemory: true, showTemperature: true, showGpu: true, refreshInterval: 3000 },
            SysTray: { iconSize: 20, spacing: 8 }
        },
        plugins: {}
    })

    property var config: clone(defaults)

    // Surface materials and palettes are intentionally separate: users can change
    // the ornament/material skin without losing their chosen accent color scheme.
    readonly property var skinPresets: ({
        bloodsteel: {
            bg: "#09090c", bgAlt: "#19171c", bgHover: "#32131a",
            surfaceTop: "#26191e", surfaceBottom: "#0c0a0e",
            frame: "#594149", rune: "#c5a47d", border: "#3b3037",
            borderActive: "#741b27", textMain: "#d7cdd0", textLight: "#fff5f4",
            textDark: "#7d7179", elementRadius: 8, radius: 11,
            font: "JetBrainsMono Nerd Font"
        },
        ashen: {
            bg: "#0c0d10", bgAlt: "#1b1d22", bgHover: "#30323a",
            surfaceTop: "#24262c", surfaceBottom: "#0c0d11",
            frame: "#59606c", rune: "#bec5d0", border: "#373b44",
            borderActive: "#676f7c", textMain: "#d0d4dc", textLight: "#f7f8fa",
            textDark: "#858b97", elementRadius: 7, radius: 10,
            font: "JetBrainsMono Nerd Font"
        },
        obsidian: {
            bg: "#08090d", bgAlt: "#11131b", bgHover: "#22283b",
            surfaceTop: "#191d2a", surfaceBottom: "#08090f",
            frame: "#434b66", rune: "#a6b3d8", border: "#2b3042",
            borderActive: "#485c9c", textMain: "#cbd1e3", textLight: "#f4f6ff",
            textDark: "#727b99", elementRadius: 5, radius: 9,
            font: "JetBrainsMono Nerd Font"
        },
        verdigris: {
            bg: "#080d0c", bgAlt: "#14201d", bgHover: "#1a332c",
            surfaceTop: "#1b2a24", surfaceBottom: "#080d0b",
            frame: "#3a6658", rune: "#a9c9a2", border: "#2a463d",
            borderActive: "#376d56", textMain: "#c7d9cf", textLight: "#f1fff6",
            textDark: "#77958a", elementRadius: 8, radius: 11,
            font: "JetBrainsMono Nerd Font"
        },
        alchemy: {
            bg: "#0a100d", bgAlt: "#18231c", bgHover: "#263a2a",
            surfaceTop: "#263327", surfaceBottom: "#0a100c",
            frame: "#64744f", rune: "#d0b77b", border: "#394a38",
            borderActive: "#8b7542", textMain: "#d7ddc8", textLight: "#fff9e8",
            textDark: "#8c987a", elementRadius: 10, radius: 13,
            font: "JetBrainsMono Nerd Font"
        },
        runes: {
            bg: "#080a12", bgAlt: "#151a2a", bgHover: "#202c48",
            surfaceTop: "#20283d", surfaceBottom: "#090b13",
            frame: "#536987", rune: "#a9d4dc", border: "#303b55",
            borderActive: "#467d9a", textMain: "#d0dceb", textLight: "#f2f8ff",
            textDark: "#7e91ab", elementRadius: 6, radius: 10,
            font: "JetBrainsMono Nerd Font"
        }
    })

    readonly property var colorSchemes: ({
        crimson: { accent: "#8a1728", accentActive: "#ff334f", accentGlow: "#ff6579" },
        violet:  { accent: "#6037a8", accentActive: "#ac83ff", accentGlow: "#c7a6ff" },
        frost:   { accent: "#286b91", accentActive: "#6acbff", accentGlow: "#a0e2ff" },
        jade:    { accent: "#20745b", accentActive: "#55d6a5", accentGlow: "#8bffcb" },
        amber:   { accent: "#8d5a1b", accentActive: "#ffc15a", accentGlow: "#ffe0a0" }
    })

    // Always expose a complete theme object. A bad/mid-reload config must not
    // make consumers such as PanelWindow evaluate `undefined.radius`.
    // Read `config` directly in the binding so all theme consumers are notified
    // when updateAppearance replaces the config object.
    readonly property var effectiveTheme: {
        const configSnapshot = config
        return safeBuildEffectiveTheme()
    }
    readonly property bool animationsEnabled: config.appearance.animations !== "off"
    readonly property bool idleEffectsEnabled: config.appearance.animations === "full" && config.appearance.glow === true && config.appearance.ornaments !== false
    readonly property bool ornamentsEnabled: config.appearance.ornaments !== false

    function safeBuildEffectiveTheme() {
        const fallback = {
            bg: "#09090c", bgAlt: "#19171c", bgHover: "#32131a",
            surfaceTop: "#26191e", surfaceBottom: "#0c0a0e",
            frame: "#594149", rune: "#c5a47d", border: "#3b3037",
            borderActive: "#741b27", accent: "#8a1728", accentActive: "#ff334f",
            accentGlow: "#ff6579", textMain: "#d7cdd0", textLight: "#fff5f4",
            textDark: "#7d7179", elementRadius: 8, radius: 11,
            font: "JetBrainsMono Nerd Font"
        }
        try {
            const result = buildEffectiveTheme()
            // Merging onto a complete palette gives every consumer safe defaults,
            // even when a custom theme intentionally defines only a few values.
            if (!isPlainObject(result))
                throw new Error("theme builder returned a non-object")
            return merge(clone(fallback), result)
        } catch (error) {
            console.warn("[GlobalState] Theme calculation failed; using safe palette:", String(error))
            return fallback
        }
    }

    function buildEffectiveTheme() {
        const currentConfig = isPlainObject(state.config) ? state.config : clone(state.defaults)
        const appearance = isPlainObject(currentConfig.appearance) ? currentConfig.appearance : ({})
        const skinName = appearance.skin || "bloodsteel"
        const schemeName = appearance.colorScheme || "crimson"
        const presets = state.skinPresets || ({})
        const schemes = state.colorSchemes || ({})
        const baseSkin = presets[skinName] || presets.bloodsteel
        const colorScheme = schemes[schemeName] || schemes.crimson
        if (!isPlainObject(baseSkin) || !isPlainObject(colorScheme))
            throw new Error("theme presets are not initialized")
        let result = merge(clone(baseSkin), clone(colorScheme))
        const configuredTheme = isPlainObject(currentConfig.theme) ? currentConfig.theme : ({})
        if (skinName === "custom" && isPlainObject(configuredTheme.customColors))
            result = merge(result, configuredTheme.customColors)
        return result
    }

    function animationDuration(baseDuration) {
        const appearance = state.config.appearance || ({})
        const mode = appearance.animations || "balanced"
        if (mode === "off") return 0
        const scaleValue = Number(appearance.motionScale)
        const scale = isFinite(scaleValue) ? Math.max(0, Math.min(3, scaleValue)) : 1.0
        if (scale === 0) return 0
        const multiplier = mode === "reduced" ? 0.35 : (mode === "full" ? 1.15 : 0.7)
        return Math.max(1, Math.round(baseDuration * multiplier * scale))
    }

    function clone(value) {
        return JSON.parse(JSON.stringify(value))
    }

    function isPlainObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }

    // Objects are merged recursively; arrays and primitive values override defaults.
    function merge(base, override) {
        let result = {}
        Object.keys(base).forEach(function (key) { result[key] = base[key] })
        Object.keys(override).forEach(function (key) {
            if (isPlainObject(base[key]) && isPlainObject(override[key])) {
                result[key] = merge(base[key], override[key])
            } else {
                result[key] = override[key]
            }
        })
        return result
    }

    function requireStringArray(values, name) {
        for (let i = 0; i < values.length; i++) {
            if (typeof values[i] !== "string" || values[i].trim() === "")
                throw new Error(name + " must contain non-empty module IDs")
        }
    }

    function requireNumber(object, key, name, minimum) {
        if (object[key] === undefined)
            return
        if (typeof object[key] !== "number" || !isFinite(object[key]) || object[key] < minimum)
            throw new Error(name + " must be a number >= " + minimum)
    }

    function applyConfig(text) {
        // Keep the stage in the diagnostic: QML bindings can fail while a new
        // configuration is committed, and a bare TypeError is not actionable.
        let stage = "parse JSON"
        try {
            const parsed = JSON.parse(text)
            stage = "validate root"
            if (!isPlainObject(parsed))
                throw new Error("the JSON root must be an object")
            if (parsed.version !== undefined && parsed.version !== 1)
                throw new Error("unsupported config version: " + parsed.version)
            if (parsed.theme !== undefined && !isPlainObject(parsed.theme))
                throw new Error("theme must be an object")
            if (parsed.appearance !== undefined && !isPlainObject(parsed.appearance))
                throw new Error("appearance must be an object")
            if (parsed.bar !== undefined && !isPlainObject(parsed.bar))
                throw new Error("bar must be an object")
            if (parsed.geometry !== undefined && !isPlainObject(parsed.geometry))
                throw new Error("geometry must be an object")
            if (parsed.layout !== undefined && !Array.isArray(parsed.layout))
                throw new Error("layout must be an array")
            if (parsed.modules !== undefined && !isPlainObject(parsed.modules))
                throw new Error("modules must be an object")
            if (parsed.plugins !== undefined && !isPlainObject(parsed.plugins))
                throw new Error("plugins must be an object")

            stage = "migrate legacy config"
            // Migrate v1 configs written before presets existed. The old palette is
            // preserved as a custom skin instead of silently changing user colors.
            let source = clone(parsed)
            const legacyColorKeys = ["bg", "bgAlt", "accent", "accentActive", "textMain"]
            const hasLegacyPalette = !source.appearance && isPlainObject(source.theme) &&
                legacyColorKeys.some(key => source.theme[key] !== undefined)
            if (hasLegacyPalette) {
                const legacyColors = clone(source.theme)
                source.appearance = { skin: "custom", colorScheme: "crimson", animations: "balanced", ornaments: true, glow: true }
                source.theme = { customColors: legacyColors }
                // Expose the new appearance controls in existing v1 installations.
                if (Array.isArray(source.layout) && source.layout.indexOf("Appearance") < 0)
                    source.layout.push("Appearance")
            }

            stage = "merge defaults"
            const merged = merge(clone(state.defaults), source)
            if (!isPlainObject(merged.appearance))
                throw new Error("appearance must be an object")
            // Normalize through local references. Avoid repeatedly dereferencing
            // nested QVariant/QML maps during validation (customColors may be
            // absent in older or hand-edited configs).
            const normalizedTheme = isPlainObject(merged.theme) ? merged.theme : ({})
            const customColors = isPlainObject(normalizedTheme.customColors) ? normalizedTheme.customColors : ({})
            normalizedTheme.customColors = customColors
            merged.theme = normalizedTheme
            if (!isPlainObject(merged.bar.layout))
                throw new Error("bar.layout must be an object")
            if (!Array.isArray(merged.bar.layout.left) ||
                !Array.isArray(merged.bar.layout.center) ||
                !Array.isArray(merged.bar.layout.right)) {
                throw new Error("bar.layout.left/center/right must be arrays")
            }
            if (!Array.isArray(merged.layout))
                throw new Error("layout must be an array")
            if (!isPlainObject(merged.geometry) || !isPlainObject(merged.theme) ||
                !isPlainObject(merged.modules) || !isPlainObject(merged.plugins)) {
                throw new Error("geometry, theme, modules and plugins must be objects")
            }

            requireStringArray(merged.bar.layout.left, "bar.layout.left")
            requireStringArray(merged.bar.layout.center, "bar.layout.center")
            requireStringArray(merged.bar.layout.right, "bar.layout.right")
            requireStringArray(merged.layout, "layout")

            requireNumber(merged.bar, "height", "bar.height", 30)
            requireNumber(merged.bar, "margin", "bar.margin", 0)
            requireNumber(merged.geometry, "width", "geometry.width", 100)
            requireNumber(merged.geometry, "height", "geometry.height", 100)
            requireNumber(merged.geometry, "marginTop", "geometry.marginTop", 0)
            requireNumber(merged.geometry, "marginRight", "geometry.marginRight", 0)
            requireNumber(merged.appearance, "motionScale", "appearance.motionScale", 0)
            if (merged.appearance.motionScale > 3)
                throw new Error("appearance.motionScale must be <= 3")
            if (["bloodsteel", "ashen", "obsidian", "verdigris", "alchemy", "runes", "custom"].indexOf(merged.appearance.skin) < 0)
                throw new Error("appearance.skin must be bloodsteel, ashen, obsidian, verdigris, alchemy, runes, or custom")
            if (["crimson", "violet", "frost", "jade", "amber"].indexOf(merged.appearance.colorScheme) < 0)
                throw new Error("appearance.colorScheme must be crimson, violet, frost, jade, or amber")
            if (["full", "balanced", "reduced", "off"].indexOf(merged.appearance.animations) < 0)
                throw new Error("appearance.animations must be full, balanced, reduced, or off")
            if (typeof merged.appearance.ornaments !== "boolean" || typeof merged.appearance.glow !== "boolean")
                throw new Error("appearance.ornaments and appearance.glow must be booleans")

            Object.keys(merged.modules).forEach(function (moduleId) {
                if (!isPlainObject(merged.modules[moduleId]))
                    throw new Error("modules." + moduleId + " must be an object")
            })
            stage = "validate theme colors"
            const colorKeys = ["bg", "bgAlt", "bgHover", "surfaceTop", "surfaceBottom", "frame", "rune", "accentGlow", "border", "borderActive", "accent", "accentActive", "textMain", "textLight", "textDark", "font"]
            const customColorKeys = Object.keys(customColors)
            for (let i = 0; i < customColorKeys.length; ++i) {
                const customKey = customColorKeys[i]
                const customValue = customColors[customKey]
                if (colorKeys.indexOf(customKey) >= 0 && typeof customValue !== "string")
                    throw new Error("theme.customColors." + customKey + " must be a string")
                if ((customKey === "elementRadius" || customKey === "radius") &&
                    (typeof customValue !== "number" || customValue < 0))
                    throw new Error("theme.customColors." + customKey + " must be a non-negative number")
            }

            Object.keys(merged.plugins).forEach(function (pluginId) {
                const plugin = merged.plugins[pluginId]
                if (!isPlainObject(plugin))
                    throw new Error("plugin " + pluginId + " must be an object")
                if (plugin.enabled !== undefined && typeof plugin.enabled !== "boolean")
                    throw new Error("plugins." + pluginId + ".enabled must be a boolean")
                if (plugin.apiVersion !== undefined && typeof plugin.apiVersion !== "number")
                    throw new Error("plugins." + pluginId + ".apiVersion must be a number")
                if (plugin.settings !== undefined && !isPlainObject(plugin.settings))
                    throw new Error("plugins." + pluginId + ".settings must be an object")
            })

            stage = "commit config and dependent bindings"
            state.config = merged
            state.configError = ""
            console.info("[GlobalState] Configuration loaded from", configFile.path)
            return true
        } catch (error) {
            state.configError = "[" + stage + "] " + String(error)
            // Include stack where the embedded QML JavaScript engine provides it;
            // this makes future schema/config errors traceable instead of opaque.
            console.warn("[GlobalState] Configuration rejected; keeping last valid config:",
                         state.configError, error && error.stack ? error.stack : "")
            return false
        }
    }

    FileView {
        id: configFile
        path: Quickshell.shellDir + "/config.json"
        blockLoading: true
        watchChanges: true

        onLoaded: state.applyConfig(text())
        onFileChanged: reload()
        onLoadFailed: error => {
            state.configError = String(error)
            console.warn("[GlobalState] Could not load config:", path, state.configError)
        }
    }

    function reloadConfig() {
        configFile.reload()
    }

    function updateAppearance(key, value) {
        const allowed = {
            skin: ["bloodsteel", "ashen", "obsidian", "verdigris", "alchemy", "runes", "custom"],
            colorScheme: ["crimson", "violet", "frost", "jade", "amber"],
            animations: ["full", "balanced", "reduced", "off"],
            ornaments: [true, false],
            glow: [true, false]
        }
        if (!Object.prototype.hasOwnProperty.call(allowed, key) || allowed[key].indexOf(value) < 0) {
            console.warn("[GlobalState] Rejected invalid appearance option:", key, value)
            return
        }
        const nextConfig = clone(state.config)
        nextConfig.appearance[key] = value
        const serialized = JSON.stringify(nextConfig, null, 2)
        // Validate and apply first. Never persist a value that was rejected by schema
        // validation or a dependent QML binding. FileView writes the accepted snapshot.
        if (!state.applyConfig(serialized)) {
            console.warn("[GlobalState] Appearance change was not applied:", key, value, state.configError)
            return
        }
        configFile.setText(serialized)
        console.info("[GlobalState] Appearance applied:", key, "=", value)
    }

    Component.onCompleted: {
        // FileView uses blocking only for startup config; subsequent file changes are async.
        if (configFile.loaded)
            applyConfig(configFile.text())
        else
            configFile.reload()
    }
}
