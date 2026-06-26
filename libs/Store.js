this.MS = this.MS || {}

MS.Store = MS.Store || (function () {

    var values = {}

    function set(key, value) {
        values[key] = value
    }

    function get(key, defaultValue) {
        var v = values[key]
        return v !== undefined ? v : defaultValue
    }

    function has(key) {
        return values[key] !== undefined
    }

    function remove(key) {
        delete values[key]
    }

    function clear() {
        values = {}
    }

    function dump() {
        return values
    }

    return {
        set: set,
        get: get,
        has: has,
        remove: remove,
        clear: clear,
        dump: dump
    }

})()